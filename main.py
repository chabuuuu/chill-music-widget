import os
import sys
import subprocess
from PyQt5.QtWidgets import (
    QApplication, QWidget, QFrame, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QSlider, QSystemTrayIcon, QMenu, QAction,
    QGraphicsDropShadowEffect, QProgressBar
)
from PyQt5.QtCore import Qt, QPoint, QSize, QTimer, QRectF
from PyQt5.QtGui import QIcon, QFont, QColor, QPixmap, QPainter, QBrush, QPen, QLinearGradient, QPainterPath

# Import psutil for system stats
import psutil

# Import local modules
import config
from visualizer import StitchWaveformVisualizer
from mpris_thread import MprisMonitorThread
from cava_thread import CavaRunnerThread
from clickable_slider import ClickableSlider

def get_cpu_temp():
    try:
        # Try psutil sensors
        temps = psutil.sensors_temperatures()
        if temps:
            for name in ['coretemp', 'acpitz', 'cpu_thermal', 'k10temp']:
                if name in temps and temps[name]:
                    return int(temps[name][0].current)
        # Try reading /sys directly on Linux
        if os.path.exists("/sys/class/thermal/thermal_zone0/temp"):
            with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
                t = int(f.read().strip())
                return int(t / 1000)
    except Exception:
        pass
    return 45  # fallback matching design HTML default

class RoundedImageLabel(QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedSize(144, 144)  # matches w-36 h-36
        self.pixmap_data = None

    def set_image(self, pixmap):
        self.pixmap_data = pixmap
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)  # Ensure ultra-smooth high-quality scaling
        
        path = QPainterPath()
        path.addRoundedRect(QRectF(0, 0, self.width(), self.height()), 16, 16)  # matches rounded-2xl
        painter.setClipPath(path)
        
        if self.pixmap_data and not self.pixmap_data.isNull():
            pw = self.pixmap_data.width()
            ph = self.pixmap_data.height()
            tw = self.width()
            th = self.height()
            
            p_aspect = pw / ph
            t_aspect = tw / th
            
            if p_aspect > t_aspect:
                # Wider: scale height to fit container, crop sides
                scaled_h = th
                scaled_w = int(th * p_aspect)
                x = (tw - scaled_w) // 2
                y = 0
            else:
                # Taller: scale width to fit container, crop top/bottom
                scaled_w = tw
                scaled_h = int(tw / p_aspect)
                x = 0
                y = (th - scaled_h) // 2
                
            painter.drawPixmap(x, y, scaled_w, scaled_h, self.pixmap_data)
        else:
            # Subtle glass fallback matching design
            painter.setBrush(QBrush(QColor(255, 255, 255, 10)))
            painter.setPen(QPen(QColor(255, 255, 255, 20), 1.0))
            painter.drawRoundedRect(QRectF(0, 0, self.width(), self.height()), 16, 16)
            
            painter.setPen(QColor(255, 255, 255, 120))
            painter.setFont(QFont("Inter", 32))
            painter.drawText(self.rect(), Qt.AlignCenter, "🎵")

class MprisChillWidget(QWidget):
    def __init__(self):
        super().__init__()
        
        # Load config
        self.config_data = config.load_config()
        
        # Size states (Redesigned horizontally: Width: 860px, Height: 230px)
        self.width_px = 860
        self.height_px = 230
        self.drag_position = QPoint()
        self.is_dragging_timeline = False
        
        # Frameless transparent desktop window attributes
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        
        self.init_ui()
        self.setFixedSize(self.width_px, self.height_px)
        self.move(self.config_data.get("x", 100), self.config_data.get("y", 100))
        
        self.start_threads()
        self.init_timers()
        self.create_tray_icon()

    def init_ui(self):
        # 1. Main outer layout
        self.outer_layout = QVBoxLayout(self)
        self.outer_layout.setContentsMargins(0, 0, 0, 0)
        
        # 2. Re-engineered glassmorphism outer card
        self.main_card = QFrame(self)
        self.main_card.setObjectName("MainCard")
        self.main_card.setFixedSize(self.width_px, self.height_px)
        
        self.card_layout = QHBoxLayout(self.main_card)
        self.card_layout.setContentsMargins(24, 24, 24, 24)  # p-6 (24px)
        self.card_layout.setSpacing(24)  # gap-6 (24px)
        
        # --- LEFT PANEL: Music Player Section (Width: 512px) ---
        self.left_panel = QFrame(self.main_card)
        self.left_panel.setFixedWidth(512)
        self.left_panel_layout = QHBoxLayout(self.left_panel)
        self.left_panel_layout.setContentsMargins(0, 0, 0, 0)
        self.left_panel_layout.setSpacing(24)  # gap-6
        
        # Album Cover Image
        self.cover_label = RoundedImageLabel(self.left_panel)
        self.left_panel_layout.addWidget(self.cover_label)
        
        # Track Info and Controls Column
        self.track_col = QWidget(self.left_panel)
        self.track_layout = QVBoxLayout(self.track_col)
        self.track_layout.setContentsMargins(0, 0, 0, 0)
        self.track_layout.setSpacing(0)
        
        # Song Title and Artist Layout
        self.title_label = QLabel("No active player", self.track_col)
        self.title_label.setObjectName("SongTitle")
        self.title_label.setFont(QFont("Inter", 16, QFont.Bold))
        self.title_label.setFixedHeight(28)
        self.track_layout.addWidget(self.title_label)
        
        self.artist_label = QLabel("Play music to visualize", self.track_col)
        self.artist_label.setObjectName("SongArtist")
        self.artist_label.setFont(QFont("Inter", 10))
        self.artist_label.setFixedHeight(18)
        self.track_layout.addWidget(self.artist_label)
        
        self.track_layout.addSpacing(6)
        
        # 15-Bar Soundwave Visualizer
        self.waveform_widget = StitchWaveformVisualizer(self.track_col, bar_count=15)
        self.track_layout.addWidget(self.waveform_widget)
        
        self.track_layout.addSpacing(8)
        
        # Progress Seek Bar and Timestamps
        self.progress_layout = QVBoxLayout()
        self.progress_layout.setSpacing(3)
        
        self.time_layout = QHBoxLayout()
        self.time_current = QLabel("00:00", self.track_col)
        self.time_current.setObjectName("TimeClockMini")
        self.time_current.setFont(QFont("monospace", 8))
        self.time_layout.addWidget(self.time_current)
        
        self.time_layout.addStretch()
        
        self.time_total = QLabel("00:00", self.track_col)
        self.time_total.setObjectName("TimeClockMini")
        self.time_total.setFont(QFont("monospace", 8))
        self.time_layout.addWidget(self.time_total)
        self.progress_layout.addLayout(self.time_layout)
        
        # Custom Cyan Slider Seekbar
        self.timeline_slider = ClickableSlider(Qt.Horizontal, self.track_col)
        self.timeline_slider.setObjectName("TimelineSlider")
        self.timeline_slider.setRange(0, 100)
        self.timeline_slider.setValue(0)
        self.timeline_slider.sliderPressed.connect(self.timeline_pressed)
        self.timeline_slider.sliderMoved.connect(self.timeline_moved)
        self.timeline_slider.sliderReleased.connect(self.timeline_released)
        self.progress_layout.addWidget(self.timeline_slider)
        self.track_layout.addLayout(self.progress_layout)
        
        self.track_layout.addSpacing(10)
        
        # Playback Controls Panel (Prev, Play/Pause, Next | Volume)
        self.controls_row = QHBoxLayout()
        self.controls_row.setSpacing(16)
        
        self.prev_btn = QPushButton("⏮", self.track_col)
        self.prev_btn.setObjectName("ControlBtn")
        self.prev_btn.setFixedSize(30, 30)
        self.prev_btn.setCursor(Qt.PointingHandCursor)
        self.prev_btn.clicked.connect(self.media_prev)
        self.controls_row.addWidget(self.prev_btn)
        
        # Circular Accent Play Button
        self.play_btn = QPushButton("▶", self.track_col)
        self.play_btn.setObjectName("PlayBtn")
        self.play_btn.setFixedSize(40, 40)
        self.play_btn.setCursor(Qt.PointingHandCursor)
        self.play_btn.clicked.connect(self.media_toggle)
        self.controls_row.addWidget(self.play_btn)
        
        self.next_btn = QPushButton("⏭", self.track_col)
        self.next_btn.setObjectName("ControlBtn")
        self.next_btn.setFixedSize(30, 30)
        self.next_btn.setCursor(Qt.PointingHandCursor)
        self.next_btn.clicked.connect(self.media_next)
        self.controls_row.addWidget(self.next_btn)
        
        self.controls_row.addStretch()
        
        # Volume group
        self.vol_btn = QPushButton("🔊", self.track_col)
        self.vol_btn.setObjectName("ControlBtn")
        self.vol_btn.setFixedSize(28, 28)
        self.vol_btn.setCursor(Qt.PointingHandCursor)
        self.vol_btn.clicked.connect(self.media_mute)
        self.controls_row.addWidget(self.vol_btn)
        
        self.vol_slider = ClickableSlider(Qt.Horizontal, self.track_col)
        self.vol_slider.setObjectName("VolumeSlider")
        self.vol_slider.setFixedWidth(64)
        self.vol_slider.setRange(0, 100)
        self.vol_slider.setValue(self.config_data.get("volume", 70))
        self.vol_slider.valueChanged.connect(self.set_media_volume)
        self.controls_row.addWidget(self.vol_slider)
        
        self.track_layout.addLayout(self.controls_row)
        
        self.left_panel_layout.addWidget(self.track_col)
        self.card_layout.addWidget(self.left_panel)
        
        # --- MIDDLE DIVIDER ---
        self.divider = QFrame(self.main_card)
        self.divider.setObjectName("DividerLine")
        self.divider.setFrameShape(QFrame.VLine)
        self.divider.setFrameShadow(QFrame.Plain)
        self.divider.setFixedWidth(1)
        self.card_layout.addWidget(self.divider)
        
        # --- RIGHT PANEL: System Info & Clock (Width: 220px) ---
        self.right_panel = QFrame(self.main_card)
        self.right_panel.setFixedWidth(220)
        self.right_layout = QVBoxLayout(self.right_panel)
        self.right_layout.setContentsMargins(8, 0, 0, 0)
        self.right_layout.setSpacing(12)
        
        # Clock Group (Time & Date)
        self.clock_group = QWidget(self.right_panel)
        self.clock_layout = QVBoxLayout(self.clock_group)
        self.clock_layout.setContentsMargins(0, 0, 0, 0)
        self.clock_layout.setSpacing(2)
        
        self.time_label = QLabel("10:42", self.clock_group)
        self.time_label.setObjectName("TimeClock")
        self.time_label.setFont(QFont("Inter", 32, QFont.Light))
        self.time_label.setFixedHeight(40)
        self.clock_layout.addWidget(self.time_label)
        
        self.date_label = QLabel("MON, 24 OCT", self.clock_group)
        self.date_label.setObjectName("DateLabel")
        self.date_label.setFont(QFont("Inter", 8, QFont.DemiBold))
        self.clock_layout.addWidget(self.date_label)
        self.right_layout.addWidget(self.clock_group)
        
        # Stats Columns (CPU, RAM, Battery, Temp)
        self.stats_group = QWidget(self.right_panel)
        self.stats_layout = QVBoxLayout(self.stats_group)
        self.stats_layout.setContentsMargins(0, 0, 0, 0)
        self.stats_layout.setSpacing(8)
        
        # CPU
        self.cpu_row = QWidget(self.stats_group)
        self.cpu_row_layout = QVBoxLayout(self.cpu_row)
        self.cpu_row_layout.setContentsMargins(0, 0, 0, 0)
        self.cpu_row_layout.setSpacing(4)
        
        self.cpu_meta = QHBoxLayout()
        self.cpu_lbl = QLabel("⚡ CPU", self.cpu_row)
        self.cpu_lbl.setObjectName("StatLabel")
        self.cpu_meta.addWidget(self.cpu_lbl)
        self.cpu_meta.addStretch()
        self.cpu_val = QLabel("0%", self.cpu_row)
        self.cpu_val.setObjectName("StatVal")
        self.cpu_meta.addWidget(self.cpu_val)
        self.cpu_row_layout.addLayout(self.cpu_meta)
        
        self.cpu_bar = QProgressBar(self.cpu_row)
        self.cpu_bar.setTextVisible(False)
        self.cpu_bar.setRange(0, 100)
        self.cpu_row_layout.addWidget(self.cpu_bar)
        self.stats_layout.addWidget(self.cpu_row)
        
        # RAM
        self.ram_row = QWidget(self.stats_group)
        self.ram_row_layout = QVBoxLayout(self.ram_row)
        self.ram_row_layout.setContentsMargins(0, 0, 0, 0)
        self.ram_row_layout.setSpacing(4)
        
        self.ram_meta = QHBoxLayout()
        self.ram_lbl = QLabel("💾 RAM", self.ram_row)
        self.ram_lbl.setObjectName("StatLabel")
        self.ram_meta.addWidget(self.ram_lbl)
        self.ram_meta.addStretch()
        self.ram_val = QLabel("0.0 GB", self.ram_row)
        self.ram_val.setObjectName("StatVal")
        self.ram_meta.addWidget(self.ram_val)
        self.ram_row_layout.addLayout(self.ram_meta)
        
        self.ram_bar = QProgressBar(self.ram_row)
        self.ram_bar.setTextVisible(False)
        self.ram_bar.setRange(0, 100)
        self.ram_row_layout.addWidget(self.ram_bar)
        self.stats_layout.addWidget(self.ram_row)
        
        # Battery
        self.bat_row = QWidget(self.stats_group)
        self.bat_row_layout = QVBoxLayout(self.bat_row)
        self.bat_row_layout.setContentsMargins(0, 0, 0, 0)
        self.bat_row_layout.setSpacing(4)
        
        self.bat_meta = QHBoxLayout()
        self.battery_lbl = QLabel("🔋 Battery", self.bat_row)
        self.battery_lbl.setObjectName("StatLabel")
        self.bat_meta.addWidget(self.battery_lbl)
        self.bat_meta.addStretch()
        self.battery_val = QLabel("100%", self.bat_row)
        self.battery_val.setObjectName("StatVal")
        self.bat_meta.addWidget(self.battery_val)
        self.bat_row_layout.addLayout(self.bat_meta)
        
        self.battery_bar = QProgressBar(self.bat_row)
        self.battery_bar.setTextVisible(False)
        self.battery_bar.setRange(0, 100)
        self.bat_row_layout.addWidget(self.battery_bar)
        self.stats_layout.addWidget(self.bat_row)
        
        # Temp
        self.temp_row = QWidget(self.stats_group)
        self.temp_row_layout = QHBoxLayout(self.temp_row)
        self.temp_row_layout.setContentsMargins(0, 2, 0, 0)
        self.temp_lbl = QLabel("🌡️ Temp", self.temp_row)
        self.temp_lbl.setObjectName("StatLabel")
        self.temp_row_layout.addWidget(self.temp_lbl)
        self.temp_row_layout.addStretch()
        self.temp_val = QLabel("45°C", self.temp_row)
        self.temp_val.setObjectName("StatVal")
        self.temp_row_layout.addWidget(self.temp_val)
        self.stats_layout.addWidget(self.temp_row)
        
        self.right_layout.addWidget(self.stats_group)
        self.card_layout.addWidget(self.right_panel)
        
        self.outer_layout.addWidget(self.main_card)
        
        # Load theme stylesheet
        self.apply_theme()

    def start_threads(self):
        # 1. MPRIS Monitor Thread
        self.mpris_thread = MprisMonitorThread(player_name="auto")
        self.mpris_thread.metadata_changed.connect(self.update_media_metadata)
        self.mpris_thread.no_player_found.connect(self.handle_no_players)
        self.mpris_thread.start()
        
        # 2. CAVA Visualizer Thread (configured to 15 bars)
        self.cava_thread = CavaRunnerThread(bar_count=15)
        self.cava_thread.bars_updated.connect(self.waveform_widget.update_bars)
        self.cava_thread.start()

    def init_timers(self):
        # 1. Timeline updates
        self.timeline_timer = QTimer(self)
        self.timeline_timer.timeout.connect(self.update_timeline)
        self.timeline_timer.start(500)
        
        # 2. System stats update timer (every 1.5 seconds)
        self.stats_timer = QTimer(self)
        self.stats_timer.timeout.connect(self.update_system_stats)
        self.stats_timer.start(1500)
        
        # 3. Clock update timer (every 1 second)
        self.clock_timer = QTimer(self)
        self.clock_timer.timeout.connect(self.update_clock)
        self.clock_timer.start(1000)
        
        # Initialize stats & clock immediately
        self.update_system_stats()
        self.update_clock()

    def run_player_cmd(self, cmd_args):
        return subprocess.run(["playerctl"] + cmd_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def update_media_metadata(self, info):
        title = info["title"]
        if len(title) > 28:
            title = title[:25] + "..."
        self.title_label.setText(title)
        
        artist = info["artist"]
        if len(artist) > 34:
            artist = artist[:31] + "..."
        self.artist_label.setText(artist)
        
        # Play / Pause status
        status = info["status"].lower()
        if "play" in status:
            self.play_btn.setText("⏸")
            self.waveform_widget.set_playing(True)
        else:
            self.play_btn.setText("▶")
            self.waveform_widget.set_playing(False)
            
        # Update Cover Art
        cover_path = info["cover_path"]
        if cover_path and os.path.exists(cover_path):
            try:
                pixmap = QPixmap(cover_path)
                if not pixmap.isNull():
                    self.cover_label.set_image(pixmap)
                else:
                    self.cover_label.set_image(None)
            except Exception:
                self.cover_label.set_image(None)
        else:
            self.cover_label.set_image(None)

    def handle_no_players(self):
        self.title_label.setText("No active player")
        self.artist_label.setText("Play music to visualize")
        self.play_btn.setText("▶")
        self.waveform_widget.set_playing(False)
        self.cover_label.set_image(None)
        self.time_current.setText("00:00")
        self.time_total.setText("00:00")
        self.timeline_slider.setValue(0)

    # --- System Stats Retreival ---
    def update_system_stats(self):
        try:
            # 1. CPU Usage
            cpu = int(psutil.cpu_percent())
            self.cpu_bar.setValue(cpu)
            self.cpu_val.setText(f"{cpu}%")
            
            # 2. RAM Usage
            mem = psutil.virtual_memory()
            ram_used_gb = mem.used / (1024**3)
            self.ram_bar.setValue(int(mem.percent))
            self.ram_val.setText(f"{ram_used_gb:.1f} GB")
            
            # 3. Battery status
            bat = psutil.sensors_battery()
            if bat is not None:
                self.battery_bar.setValue(int(bat.percent))
                if bat.power_plugged:
                    self.battery_lbl.setText("🔌 Battery")
                else:
                    self.battery_lbl.setText("🔋 Battery")
                self.battery_val.setText(f"{int(bat.percent)}%")
            else:
                self.battery_bar.setValue(100)
                self.battery_lbl.setText("🔋 Battery")
                self.battery_val.setText("100%")
                
            # 4. Temperature
            temp = get_cpu_temp()
            self.temp_val.setText(f"{temp}°C")
            
        except Exception as e:
            print(f"Error updating system stats: {e}")

    # --- Clock & Calendar updates ---
    def update_clock(self):
        from datetime import datetime
        now = datetime.now()
        self.time_label.setText(now.strftime("%H:%M"))
        self.date_label.setText(now.strftime("%a, %d %b").upper())

    # --- Timeline Seeking ---
    def update_timeline(self):
        if self.is_dragging_timeline:
            return
            
        try:
            res = self.run_player_cmd(["position"])
            pos_str = res.stdout.strip()
            pos = float(pos_str) if pos_str else 0.0
            
            res = self.run_player_cmd(["metadata", "mpris:length"])
            len_str = res.stdout.strip()
            length = float(len_str) / 1000000.0 if len_str else 0.0
            
            if length > 0:
                self.timeline_slider.blockSignals(True)
                self.timeline_slider.setRange(0, int(length))
                self.timeline_slider.setValue(int(pos))
                self.timeline_slider.blockSignals(False)
                
                pos_m, pos_s = divmod(int(pos), 60)
                len_m, len_s = divmod(int(length), 60)
                self.time_current.setText(f"{pos_m:02d}:{pos_s:02d}")
                self.time_total.setText(f"{len_m:02d}:{len_s:02d}")
            else:
                self.timeline_slider.setRange(0, 100)
                self.timeline_slider.setValue(0)
                self.time_current.setText("00:00")
                self.time_total.setText("00:00")
        except Exception:
            pass

    def timeline_pressed(self):
        self.is_dragging_timeline = True

    def timeline_moved(self, val):
        try:
            pos_m, pos_s = divmod(val, 60)
            self.time_current.setText(f"{pos_m:02d}:{pos_s:02d}")
        except Exception:
            pass

    def timeline_released(self):
        self.is_dragging_timeline = False
        val = self.timeline_slider.value()
        self.run_player_cmd(["position", str(val)])

    # --- Media Triggers ---
    def media_toggle(self):
        self.run_player_cmd(["play-pause"])

    def media_next(self):
        self.run_player_cmd(["next"])

    def media_prev(self):
        self.run_player_cmd(["previous"])

    def set_media_volume(self, val):
        self.config_data["volume"] = val
        config.save_config(self.config_data)
        
        # Dùng pactl để chỉnh âm lượng tổng của hệ thống thay vì âm lượng mpris (nhiều app không support mpris volume)
        subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{val}%"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        if val == 0:
            self.vol_btn.setText("🔇")
        elif val < 40:
            self.vol_btn.setText("🔈")
        elif val < 75:
            self.vol_btn.setText("🔉")
        else:
            self.vol_btn.setText("🔊")

    def media_mute(self):
        is_muted = not self.config_data.get("muted", False)
        self.config_data["muted"] = is_muted
        config.save_config(self.config_data)
        
        if is_muted:
            subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "1"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.vol_btn.setText("🔇")
            self.vol_slider.setValue(0)
        else:
            subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            vol = self.config_data.get("volume", 70)
            self.set_media_volume(vol)
            self.vol_slider.setValue(vol)

    # --- Mouse Resizing, Locking & Dragging ---
    def toggle_lock(self):
        self.config_data["locked"] = not self.config_data.get("locked", False)
        config.save_config(self.config_data)
        self.update_lock_button()

    def update_lock_button(self):
        # We handle tooltips or UI updates if needed
        pass

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            if not self.config_data.get("locked", False):
                self.drag_position = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if event.buttons() == Qt.LeftButton:
            if not self.config_data.get("locked", False):
                self.move(event.globalPos() - self.drag_position)
                self.config_data["x"] = self.x()
                self.config_data["y"] = self.y()
                config.save_config(self.config_data)
            event.accept()

    def mouseReleaseEvent(self, event):
        if not self.config_data.get("locked", False):
            self.config_data["x"] = self.x()
            self.config_data["y"] = self.y()
            config.save_config(self.config_data)
        event.accept()

    # --- Context Menu Right Click ---
    def contextMenuEvent(self, event):
        menu = QMenu(self)
        menu.setObjectName("LofiMenu")
        
        lock_act = QAction("🔒 Lock Widget" if not self.config_data.get("locked", False) else "🔓 Unlock Widget", self)
        lock_act.triggered.connect(self.toggle_lock)
        menu.addAction(lock_act)
        
        stays_bottom = bool(self.windowFlags() & Qt.WindowStaysOnBottomHint)
        bottom_act = QAction("✓ Pin to Desktop" if stays_bottom else "Pin to Desktop", self)
        bottom_act.triggered.connect(self.toggle_desktop_mode)
        menu.addAction(bottom_act)
        
        menu.addSeparator()
        
        # Startup Option
        auto_enabled = self.config_data.get("autostart", False)
        auto_act = QAction("✓ Launch on Startup" if auto_enabled else "Launch on Startup", self)
        auto_act.triggered.connect(self.toggle_autostart_option)
        menu.addAction(auto_act)
        
        menu.addSeparator()
        
        exit_act = QAction("❌ Exit Widget", self)
        exit_act.triggered.connect(self.close_widget)
        menu.addAction(exit_act)
        
        menu.exec_(event.globalPos())

    def toggle_desktop_mode(self):
        flags = self.windowFlags()
        if flags & Qt.WindowStaysOnBottomHint:
            self.setWindowFlags(Qt.FramelessWindowHint | Qt.Tool)
        else:
            self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint | Qt.Tool)
        self.show()

    def toggle_autostart_option(self):
        val = not self.config_data.get("autostart", False)
        self.config_data["autostart"] = val
        config.save_config(self.config_data)
        config.toggle_autostart(val)

    # --- System Tray ---
    def create_tray_icon(self):
        self.tray_icon = QSystemTrayIcon(self)
        self.tray_icon.setIcon(QIcon.fromTheme("media-playback-start", QIcon()))
        
        tray_menu = QMenu()
        tray_menu.setObjectName("TrayMenu")
        
        show_act = QAction("Toggle Widget Visiblity", self)
        show_act.triggered.connect(self.toggle_visibility)
        tray_menu.addAction(show_act)
        
        tray_menu.addSeparator()
        
        exit_act = QAction("Exit Widget", self)
        exit_act.triggered.connect(self.close_widget)
        tray_menu.addAction(exit_act)
        
        self.tray_icon.setContextMenu(tray_menu)
        self.tray_icon.show()
        
    def toggle_visibility(self):
        if self.isVisible():
            self.hide()
        else:
            self.show()

    def close_widget(self):
        self.cava_thread.stop()
        self.mpris_thread.stop()
        self.cava_thread.wait()
        self.mpris_thread.wait()
        self.tray_icon.hide()
        QApplication.quit()

    # --- High-fidelity QSS Stylesheet matching stitch_macos design 100% ---
    def apply_theme(self):
        qss = """
            #MainCard {
                background-color: rgba(255, 255, 255, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.2);
                border-radius: 40px;
            }
            #MainCard:hover {
                border: 1px solid rgba(20, 255, 236, 0.5);
            }
            #DividerLine {
                color: rgba(255, 255, 255, 0.1);
                background-color: rgba(255, 255, 255, 0.1);
            }
            #SongTitle {
                color: #ffffff;
                font-family: 'Inter', 'Sans-Serif';
                font-size: 22px;
                font-weight: 600;
            }
            #SongArtist {
                color: rgba(209, 213, 219, 0.85);
                font-family: 'Inter', 'Sans-Serif';
                font-size: 13px;
                font-weight: 500;
            }
            #TimeClock {
                color: #ffffff;
                font-family: 'Inter', 'Sans-Serif';
                font-size: 34px;
                font-weight: 300;
            }
            #DateLabel {
                color: rgba(209, 213, 219, 0.8);
                font-family: 'Inter', 'Sans-Serif';
                font-size: 9.5px;
                font-weight: 500;
                letter-spacing: 1.5px;
            }
            #StatLabel {
                color: rgba(209, 213, 219, 0.8);
                font-family: 'Inter', 'Sans-Serif';
                font-size: 10px;
                font-weight: 500;
            }
            #StatVal {
                color: #14ffec;
                font-family: 'Inter', 'Sans-Serif';
                font-size: 10px;
                font-weight: bold;
            }
            QProgressBar {
                background-color: rgba(255, 255, 255, 0.1);
                border: none;
                border-radius: 3px;
                max-height: 6px;
                min-height: 6px;
            }
            QProgressBar::chunk {
                background-color: #14ffec;
                border-radius: 3px;
            }
            #ControlBtn {
                background: transparent;
                color: rgba(209, 213, 219, 0.85);
                border: none;
                font-size: 16px;
            }
            #ControlBtn:hover {
                color: #ffffff;
            }
            #PlayBtn {
                background-color: #14ffec;
                color: #0c0f12;
                border: none;
                border-radius: 20px;
                font-size: 16px;
                font-weight: bold;
            }
            #PlayBtn:hover {
                background-color: rgba(20, 255, 236, 0.85);
            }
            #TimeClockMini {
                color: #ffffff;
                font-family: 'monospace';
                font-size: 11px;
            }
            #TimelineSlider::groove:horizontal {
                background: rgba(255, 255, 255, 0.2);
                height: 4px;
                border-radius: 2px;
            }
            #TimelineSlider::sub-page:horizontal {
                background: #14ffec;
                border-radius: 2px;
            }
            #TimelineSlider::handle:horizontal {
                background: #14ffec;
                width: 12px;
                height: 12px;
                margin-top: -4px;
                border-radius: 6px;
            }
            #VolumeSlider::groove:horizontal {
                background: rgba(255, 255, 255, 0.2);
                height: 3px;
                border-radius: 1.5px;
            }
            #VolumeSlider::sub-page:horizontal {
                background: #14ffec;
                border-radius: 1.5px;
            }
            #VolumeSlider::handle:horizontal {
                background: #14ffec;
                width: 8px;
                height: 8px;
                margin-top: -2.5px;
                border-radius: 4px;
            }
            QMenu#LofiMenu, QMenu#TrayMenu {
                background-color: #0c0f12;
                color: #ffffff;
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 8px;
                padding: 4px;
                font-family: 'Inter';
                font-size: 9pt;
            }
            QMenu#LofiMenu::item, QMenu#TrayMenu::item {
                padding: 6px 20px;
                border-radius: 4px;
            }
            QMenu#LofiMenu::item:selected, QMenu#TrayMenu::item:selected {
                background-color: rgba(20, 255, 236, 0.15);
                color: #ffffff;
            }
        """
        self.setStyleSheet(qss)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--check-imports":
        print("Success: Imports verified!")
        sys.exit(0)
        
    app = QApplication(sys.argv)
    widget = MprisChillWidget()
    widget.show()
    sys.exit(app.exec_())
