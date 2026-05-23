<div align="center">

# 🎵 Chill Music Widget

**A stunning glassmorphism desktop music player & system stats widget for Linux**

*Built with Python & PyQt5 · Powered by MPRIS & CAVA*

![Python](https://img.shields.io/badge/Python-3.8+-3776AB?style=for-the-badge&logo=python&logoColor=white)
![PyQt5](https://img.shields.io/badge/PyQt5-5.15+-41CD52?style=for-the-badge&logo=qt&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-Desktop-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-cyan?style=for-the-badge)

</div>

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎨 **Glassmorphism UI** | Stunning frosted white glass widget that floats above your desktop wallpaper |
| 🖼️ **Album Art** | Auto-fetches and renders current track's album art with smooth rounded corners |
| 🌊 **Live Sound Wave** | 15-bar real-time audio visualizer powered by CAVA — syncs with your music |
| ⏱️ **Seek Bar** | Interactive seek slider with live timestamps — drag to jump anywhere in a track |
| 🎮 **Media Controls** | Prev / Play-Pause / Next + volume slider, controlling any MPRIS-compatible player |
| 🕐 **Clock & Date** | Live digital clock and calendar display |
| 💻 **CPU Usage** | Real-time CPU load percentage with a glowing progress bar |
| 🧠 **RAM Usage** | Live memory usage in GB with a glowing progress bar |
| 🔋 **Battery** | Battery percentage with smart charging detection (🔌/🔋) |
| 🌡️ **Temperature** | Live CPU temperature from system sensors |

---

## 🎬 Compatibility

Works with **any MPRIS-compatible music player** including:
- 🎵 YouTube Music Desktop App (electron)
- 🎵 Spotify Desktop
- 🎵 VLC Media Player
- 🎵 Tauon Music Box
- 🎵 Rhythmbox, Audacious, Clementine
- 🎵 Any Chromium/Firefox-based web player

---

## 📦 Installation

### Quick Install (Recommended)

```bash
git clone https://github.com/chabuuuu/chill-music-widget.git
cd chill-music-widget
bash install.sh
```

### Manual Install

**1. Install system dependencies:**

```bash
# Ubuntu / Debian
sudo apt-get install python3 python3-pip python3-pyqt5 playerctl cava

# Arch Linux
sudo pacman -S python python-pip python-pyqt5 playerctl cava

# Fedora
sudo dnf install python3 python3-pip python3-qt5 playerctl
# CAVA on Fedora: build from source https://github.com/karlstav/cava
```

**2. Install Python packages:**

```bash
pip3 install --user PyQt5 psutil
```

**3. Run the widget:**

```bash
python3 main.py
```

---

## 🚀 Usage

After installation, you can:

- **Launch from App Menu:** Search for `Chill Music Widget` in your applications
- **Run directly:**
  ```bash
  python3 ~/.local/share/chill-music-widget/main.py
  ```
- **Right-click the widget** to access the context menu:
  - 🔒 Lock / Unlock position
  - 📌 Pin to Desktop (stays behind all windows)
  - 🚀 Enable Launch on Startup
  - ❌ Exit

---

## 🛠️ Project Structure

```
chill-music-widget/
├── main.py           # Main widget window, UI layout & system stats
├── visualizer.py     # 15-bar soundwave visualizer (60 FPS animation)
├── mpris_thread.py   # MPRIS media metadata monitor thread
├── cava_thread.py    # CAVA audio visualizer data thread
├── config.py         # Config load/save & autostart management
├── install.sh        # One-command Linux installer
└── requirements.txt  # Python dependencies
```

---

## ⚙️ Requirements

| Dependency | Version | Purpose |
|---|---|---|
| Python | 3.8+ | Runtime |
| PyQt5 | 5.15+ | GUI framework |
| psutil | 5.9+ | System stats (CPU, RAM, Battery, Temp) |
| playerctl | Any | MPRIS media player control |
| cava | Any | Audio visualizer data source (optional) |

> **Note:** If CAVA is not installed, the soundwave visualizer will gracefully fall back to a smooth ambient animation.

---

## 🎨 Design Credit

Widget design inspired by the **macOS Stitch Music Widget** glassmorphism concept.

---

## 📄 License

This project is open source under the [MIT License](LICENSE).

Made with ❤️ by [@chabuuuu](https://github.com/chabuuuu)
