#!/usr/bin/env bash
# install.sh - One-command installer for Chill Music Widget
# Works on Ubuntu/Debian/Arch Linux distributions
# Usage: bash install.sh

set -e

WIDGET_DIR="$HOME/.local/share/chill-music-widget"
CONFIG_DIR="$HOME/.config/chill-music-widget"
DESKTOP_FILE="$HOME/.local/share/applications/chill-music.desktop"
AUTOSTART_FILE="$HOME/.config/autostart/chill-music.desktop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║     🎵  Chill Music Widget Installer       ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# ── 1. Detect package manager ─────────────────────────────────────────────────
if command -v apt-get &>/dev/null; then
    PKG="apt"
elif command -v pacman &>/dev/null; then
    PKG="pacman"
elif command -v dnf &>/dev/null; then
    PKG="dnf"
else
    echo "⚠️  Could not detect package manager. Please install dependencies manually."
    PKG="unknown"
fi

# ── 2. Install system dependencies ────────────────────────────────────────────
echo "📦 Installing system dependencies..."
if [ "$PKG" = "apt" ]; then
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip python3-pyqt5 playerctl cava 2>/dev/null || true
elif [ "$PKG" = "pacman" ]; then
    sudo pacman -Sy --noconfirm python python-pip python-pyqt5 playerctl cava 2>/dev/null || true
elif [ "$PKG" = "dnf" ]; then
    sudo dnf install -y python3 python3-pip python3-qt5 playerctl 2>/dev/null || true
    echo "ℹ️  CAVA may need to be installed from AUR or built from source on Fedora."
fi

# ── 3. Install Python dependencies ────────────────────────────────────────────
echo "🐍 Installing Python dependencies..."
pip3 install --user -q PyQt5 psutil 2>/dev/null || true

# ── 4. Copy widget files ───────────────────────────────────────────────────────
echo "📂 Installing widget files to $WIDGET_DIR..."
mkdir -p "$WIDGET_DIR"
cp "$SCRIPT_DIR"/*.py "$WIDGET_DIR/"
chmod +x "$WIDGET_DIR/main.py"

# ── 5. Create config dir ──────────────────────────────────────────────────────
mkdir -p "$CONFIG_DIR"

# ── 6. Create .desktop launcher ──────────────────────────────────────────────
echo "🖥️  Creating application launcher..."
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Chill Music Widget
Comment=Glassmorphism desktop music player & system stats widget
Exec=python3 "$WIDGET_DIR/main.py"
Icon=media-playback-start
Terminal=false
Type=Application
Categories=AudioVideo;Player;
StartupNotify=true
EOF
chmod +x "$DESKTOP_FILE"

# ── 7. Also place on Desktop ──────────────────────────────────────────────────
if [ -d "$HOME/Desktop" ]; then
    cp "$DESKTOP_FILE" "$HOME/Desktop/chill-music.desktop"
    chmod +x "$HOME/Desktop/chill-music.desktop"
    echo "🔗 Desktop shortcut created."
fi

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   ✅  Installation complete!               ║"
echo "║                                            ║"
echo "║   Run widget:                              ║"
echo "║   python3 ~/.local/share/               ║"
echo "║           chill-music-widget/main.py       ║"
echo "║                                            ║"
echo "║   Or launch from your app menu:            ║"
echo "║   Search for \"Chill Music Widget\"          ║"
echo "╚════════════════════════════════════════════╝"
echo ""
