import os
import subprocess
from PyQt5.QtCore import QThread, pyqtSignal

CONFIG_DIR = os.path.expanduser("~/.config/chill-music-widget")
CAVA_CONFIG = os.path.join(CONFIG_DIR, "cava.conf")

class CavaRunnerThread(QThread):
    # Emits a list of integers representing the height of each bar
    bars_updated = pyqtSignal(list)

    def __init__(self, bar_count=20):
        super().__init__()
        self.bar_count = bar_count
        self.running = False
        self.process = None

    def ensure_cava_config(self):
        os.makedirs(CONFIG_DIR, exist_ok=True)
        # Create a standard config that pipes ASCII values separated by commas
        config_content = f"""
[general]
bars = {self.bar_count}
framerate = 60
autosens = 1
overshoot = 20

[input]
; CAVA automatically selects the best backend (PipeWire, PulseAudio, or ALSA)

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_int = 100
bar_delimiter = 44
"""
        with open(CAVA_CONFIG, "w", encoding="utf-8") as f:
            f.write(config_content.strip())

    def run(self):
        self.ensure_cava_config()
        self.running = True
        
        try:
            # Start CAVA ngầm, chuyển hướng stdout để đọc và loại bỏ stderr
            self.process = subprocess.Popen(
                ["cava", "-p", CAVA_CONFIG],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1
            )
            
            # Đọc dòng đầu ra của CAVA trong một vòng lặp nhanh
            while self.running and self.process.poll() is None:
                line = self.process.stdout.readline()
                if not line:
                    break
                    
                line = line.strip()
                if not line:
                    continue
                    
                try:
                    # Parse chuỗi "12,14,20,..." thành list số nguyên
                    parts = line.split(",")
                    if len(parts) >= self.bar_count:
                        # Extract the first N bars
                        values = [int(x) for x in parts[:self.bar_count]]
                        self.bars_updated.emit(values)
                except ValueError:
                    pass
                    
        except Exception as e:
            print(f"Error in CAVA thread: {e}")
        finally:
            self.stop()

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
