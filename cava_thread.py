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
        # CAVA only outputs an even number of bars in raw ASCII mode.
        # If the requested bar count is odd, we configure CAVA with the next even number
        # so that it doesn't round down, and then we slice to the requested count in the parser.
        cava_bars = self.bar_count
        if cava_bars % 2 != 0:
            cava_bars += 1

        # Create a standard config that pipes ASCII values separated by commas
        config_content = f"""
[general]
bars = {cava_bars}
framerate = 60
autosens = 0
sensitivity = 50

[smoothing]
monstercat = 0
integral = 50
gravity = 150
noise_reduction = 0.77

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
                    # Loại bỏ dấu phẩy thừa ở cuối dòng trước khi split
                    line_clean = line.rstrip(",")
                    parts = line_clean.split(",")
                    
                    values = [int(x) for x in parts if x.strip()]
                    
                    if len(values) >= self.bar_count:
                        # Trích xuất số lượng cột mong muốn
                        self.bars_updated.emit(values[:self.bar_count])
                    elif len(values) > 0:
                        # Nếu thiếu, bù đắp bằng các giá trị 0
                        values += [0] * (self.bar_count - len(values))
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
