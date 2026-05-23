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
        self.bars = [0.2] * bar_count  # start with 20% height
        self.target_bars = [0.2] * bar_count
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
        # Maps raw CAVA values (0-100) to 0.2-1.0
        for i in range(min(len(values), self.bar_count)):
            # Normalize to 0.2 - 1.0 range
            val = 0.2 + (float(values[i]) / 100.0) * 0.8
            self.target_bars[i] = min(1.0, max(0.2, val))

    def update_animation(self):
        self.ambient_time += 0.05
        has_active_signal = any(x > 0.21 for x in self.target_bars)
        
        for i in range(self.bar_count):
            # Smoothly transition height (exponential decay)
            decay = 0.3 if self.target_bars[i] > self.bars[i] else 0.15
            self.bars[i] = self.bars[i] * (1.0 - decay) + self.target_bars[i] * decay
            
            # Ambient float if not playing or silent
            if not self.is_playing or not has_active_signal:
                # Generate a beautiful flowing sine wave pattern across the 15 bars
                phase = self.ambient_time + i * 0.35
                amplitude = 0.4 + math.sin(phase) * 0.2 + math.cos(phase * 0.6) * 0.1
                self.bars[i] = max(0.2, min(0.9, amplitude))
                self.target_bars[i] = 0.2
                
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
