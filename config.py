import os
import json
import shutil

APP_DIR = os.path.expanduser("~/.local/share/chill-music-widget")
CONFIG_DIR = os.path.expanduser("~/.config/chill-music-widget")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
AUTOSTART_DIR = os.path.expanduser("~/.config/autostart")
DESKTOP_FILE_NAME = "chill-music.desktop"

DEFAULT_CONFIG = {
    "x": 100,
    "y": 100,
    "width": 640,
    "height": 230,
    "locked": False,
    "volume": 70,
    "muted": False,
    "theme": "misty_forest",
    "autostart": False,
    "music_folder": "",
    "last_category": "",
    "last_track_index": 0
}

def ensure_dirs():
    os.makedirs(APP_DIR, exist_ok=True)
    os.makedirs(CONFIG_DIR, exist_ok=True)

def load_config():
    ensure_dirs()
    if not os.path.exists(CONFIG_FILE):
        save_config(DEFAULT_CONFIG)
        return DEFAULT_CONFIG.copy()
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            # Merge defaults for backward compatibility
            config = DEFAULT_CONFIG.copy()
            config.update(data)
            return config
    except Exception:
        return DEFAULT_CONFIG.copy()

def save_config(config):
    ensure_dirs()
    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=4, ensure_ascii=False)
    except Exception as e:
        print(f"Error saving config: {e}")

def toggle_autostart(enable):
    os.makedirs(AUTOSTART_DIR, exist_ok=True)
    autostart_file = os.path.join(AUTOSTART_DIR, DESKTOP_FILE_NAME)
    desktop_source = os.path.expanduser(f"~/Desktop/{DESKTOP_FILE_NAME}")
    local_source = os.path.join(APP_DIR, DESKTOP_FILE_NAME)
    
    # Try to find a valid desktop file source
    source = None
    if os.path.exists(local_source):
        source = local_source
    elif os.path.exists(desktop_source):
        source = desktop_source
        
    if enable:
        if source:
            try:
                shutil.copy(source, autostart_file)
                # Ensure it is executable
                os.chmod(autostart_file, 0o755)
            except Exception as e:
                print(f"Error setting autostart: {e}")
    else:
        if os.path.exists(autostart_file):
            try:
                os.remove(autostart_file)
            except Exception as e:
                print(f"Error removing autostart: {e}")
