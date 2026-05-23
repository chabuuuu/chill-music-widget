import os
import subprocess
import urllib.request
import urllib.parse
import hashlib
from PyQt5.QtCore import QThread, pyqtSignal

CACHE_DIR = os.path.expanduser("~/.cache/chill-music-widget/covers")

class MprisMonitorThread(QThread):
    # Emits a dictionary of track info: status, title, artist, cover_path, player
    metadata_changed = pyqtSignal(dict)
    
    # Emits when there are no active players found
    no_player_found = pyqtSignal()

    def __init__(self, player_name="auto"):
        super().__init__()
        self.player_name = player_name
        self.running = False
        self.process = None
        os.makedirs(CACHE_DIR, exist_ok=True)

    def set_player_name(self, player_name):
        self.player_name = player_name

    def download_cover(self, url):
        if not url or not (url.startswith("http://") or url.startswith("https://")):
            return None
            
        try:
            url_hash = hashlib.md5(url.encode('utf-8')).hexdigest()
            ext = ".jpg"
            if ".png" in url.lower():
                ext = ".png"
            local_path = os.path.join(CACHE_DIR, f"{url_hash}{ext}")
            
            # Cache check
            if os.path.exists(local_path):
                return local_path
                
            req = urllib.request.Request(
                url, 
                headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
            )
            with urllib.request.urlopen(req, timeout=4) as response:
                with open(local_path, "wb") as f:
                    f.write(response.read())
            return local_path
        except Exception as e:
            print(f"Error downloading cover art: {e}")
            return None

    def run(self):
        self.running = True
        
        # Format string using unique delimiters
        fmt = "{{status}}[DELIM]{{title}}[DELIM]{{artist}}[DELIM]{{mpris:artUrl}}[DELIM]{{playerName}}"
        
        while self.running:
            try:
                # Build command to follow metadata events
                cmd = ["playerctl"]
                if self.player_name != "auto":
                    cmd.extend(["-p", self.player_name])
                cmd.extend(["metadata", "--follow", "--format", fmt])
                
                self.process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1
                )
                
                # Check if it failed immediately (e.g. no active players)
                self.check_initial_status()
                
                while self.running and self.process.poll() is None:
                    line = self.process.stdout.readline()
                    if not line:
                        break
                        
                    line = line.strip()
                    if not line:
                        continue
                        
                    self.parse_and_emit(line)
                    
            except Exception as e:
                print(f"Error in MPRIS thread: {e}")
                
            # If process terminated, wait a second and retry
            self.msleep(1500)

    def check_initial_status(self):
        try:
            fmt = "{{status}}[DELIM]{{title}}[DELIM]{{artist}}[DELIM]{{mpris:artUrl}}[DELIM]{{playerName}}"
            cmd = ["playerctl"]
            if self.player_name != "auto":
                cmd.extend(["-p", self.player_name])
            cmd.extend(["metadata", "--format", fmt])
            
            res = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=1.0
            )
            output = res.stdout.strip()
            if output and "[DELIM]" in output:
                self.parse_and_emit(output)
            else:
                self.no_player_found.emit()
        except Exception:
            self.no_player_found.emit()

    def parse_and_emit(self, line):
        try:
            parts = line.split("[DELIM]")
            if len(parts) >= 5:
                status = parts[0].strip()
                title = parts[1].strip()
                artist = parts[2].strip()
                art_url = parts[3].strip()
                player = parts[4].strip()
                
                # Default empty states
                if not title:
                    title = "Unknown Song"
                if not artist:
                    artist = "Unknown Artist"
                    
                local_cover = None
                
                # Parse Art URL
                if art_url:
                    if art_url.startswith("file://"):
                        # Extract and decode local file path
                        file_path = art_url[7:]
                        local_cover = urllib.parse.unquote(file_path)
                    elif art_url.startswith("http://") or art_url.startswith("https://"):
                        # Download web URL in thread
                        local_cover = self.download_cover(art_url)
                
                info = {
                    "status": status,
                    "title": title,
                    "artist": artist,
                    "cover_path": local_cover if (local_cover and os.path.exists(local_cover)) else "",
                    "player": player
                }
                self.metadata_changed.emit(info)
        except Exception as e:
            print(f"Error parsing metadata line: {e}")

    def stop(self):
        self.running = False
        if self.process:
            try:
                self.process.terminate()
                self.process.wait(timeout=1.0)
            except Exception:
                try:
                    self.process.kill()
                except Exception:
                    pass
            self.process = None
