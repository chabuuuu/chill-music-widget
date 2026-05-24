#!/usr/bin/env python3
import os
import sys
import subprocess
import time

CONFIG_PATH = os.path.expanduser("~/.config/chill-music-widget/cava_plasmoid.conf")
OUTPUT_PATH = "/dev/shm/chill_music_cava.txt"

def main():
    # Warm up and wait for config file
    for _ in range(10):
        if os.path.exists(CONFIG_PATH):
            break
        time.sleep(0.3)
        
    try:
        # Launch CAVA in line-buffered mode
        process = subprocess.Popen(
            ["cava", "-p", CONFIG_PATH],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1
        )
        
        while True:
            line = process.stdout.readline()
            if not line:
                break
            line = line.strip()
            if not line:
                continue
                
            # Overwrite the shared memory file instantly with zero latency
            try:
                with open(OUTPUT_PATH, "w") as f:
                    f.write(line)
            except Exception:
                pass
    except Exception:
        pass
    finally:
        # Cleanup
        try:
            os.remove(OUTPUT_PATH)
        except Exception:
            pass

if __name__ == "__main__":
    main()
