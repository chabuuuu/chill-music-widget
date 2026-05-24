import math
import random
from PyQt5.QtWidgets import QWidget
from PyQt5.QtCore import QTimer, Qt, QRectF
from PyQt5.QtGui import QPainter, QColor, QBrush

class StitchWaveformVisualizer(QWidget):
    def __init__(self, parent=None, bar_count=15):
        super().__init__(parent)
        self.bar_count = bar_count
        self.is_playing = False
        self.bars = [0.12] * bar_count  # start with 12% height
        self.target_bars = [0.12] * bar_count
        self.ambient_time = 0.0
        
        # 60 FPS repainting timer for fluid updates (approx 16ms)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_animation)
        self.timer.start(16)
        
        self.setFixedHeight(24)  # Matches h-6 (24px) in design
        self.setMinimumWidth(180)

    def set_playing(self, playing):
        self.is_playing = playing

    def update_bars(self, values):
        for i in range(min(len(values), self.bar_count)):
            raw = float(values[i]) / 100.0
            
            # Cân bằng tần số: Bass (i nhỏ) giảm lực, Treble (i lớn) tăng lực
            freq_balance = 0.8 + (i / max(1, self.bar_count - 1)) * 0.4
            
            # Giảm power curve xuống 1.2 vì đã tắt autosens (dữ liệu thật hơn)
            dynamic_val = math.pow(raw, 1.2) * freq_balance
            
            # Ép xung multiplier xuống mức rất thấp (0.55) để đảm bảo không bao giờ bị dựng ngược tất cả các cột
            val = 0.12 + dynamic_val * 0.55
            self.target_bars[i] = min(0.95, max(0.12, val))

    def update_animation(self):
        self.ambient_time += 0.05
        
        for i in range(self.bar_count):
            # Smoothly transition height (exponential decay)
            decay = 0.35 if self.target_bars[i] > self.bars[i] else 0.25
            self.bars[i] = self.bars[i] * (1.0 - decay) + self.target_bars[i] * decay
            
            # Ambient float only when paused
            if not self.is_playing:
                # Generate a beautiful flowing sine wave pattern across the 15 bars
                phase = self.ambient_time + i * 0.35
                amplitude = 0.4 + math.sin(phase) * 0.2 + math.cos(phase * 0.6) * 0.1
                self.bars[i] = max(0.12, min(0.9, amplitude))
                self.target_bars[i] = 0.12
                
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        w = self.width()
        h = self.height()
        
        # Draw 15 bars centered
        bar_w = 3.0
        gap = 4.0
        
        # Calculate start position to center the bars horizontally
        total_width = self.bar_count * bar_w + (self.bar_count - 1) * gap
        start_x = (w - total_width) / 2.0
        
        cyan_color = QColor(20, 255, 236)  # #14ffec
        painter.setBrush(QBrush(cyan_color))
        painter.setPen(Qt.NoPen)
        
        for i in range(self.bar_count):
            bar_height = self.bars[i] * h
            # Draw fully rounded pill-shaped bar
            x = start_x + i * (bar_w + gap)
            y = (h - bar_height) / 2.0  # Center vertically like in the design (items-center)
            painter.drawRoundedRect(QRectF(x, y, bar_w, bar_height), 1.5, 1.5)
