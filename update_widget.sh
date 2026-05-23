#!/usr/bin/env bash
# update_widget.sh - Rebuild, reinstall and refresh Chill Music Widget Plasmoid
# Usage: bash update_widget.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_NAME="com.chabuuuu.chillmusicwidget"
PLASMOID_DIR="$SCRIPT_DIR/$PLASMOID_NAME"
ZIP_FILE="$SCRIPT_DIR/$PLASMOID_NAME.plasmoid"

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   💎  Chill Music Widget QML Plasmoid      ║"
echo "║          Rebuilder & Reinstaller           ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# 1. Verification
if [ ! -d "$PLASMOID_DIR" ]; then
    echo "❌ Error: Could not find directory $PLASMOID_NAME at $SCRIPT_DIR"
    exit 1
fi

# 2. Package
echo "📦 Packaging QML Plasmoid into zip file..."
cd "$SCRIPT_DIR"
rm -f "$ZIP_FILE"
zip -q -r "$ZIP_FILE" "$PLASMOID_NAME/"
echo "✅ Packaged successfully: $PLASMOID_NAME.plasmoid"

# 3. Uninstall old version
echo "🧹 Uninstalling old version from system..."
if kpackagetool5 -r "$PLASMOID_NAME" &>/dev/null; then
    echo "✅ Uninstalled old version successfully."
else
    echo "ℹ️  No old version found or already uninstalled."
fi

# 4. Install new version
echo "🚀 Installing new QML version to KDE system..."
if kpackagetool5 -t Plasma/Applet -i "$PLASMOID_NAME"; then
    echo "✅ Installed new version successfully!"
else
    echo "❌ Error installing widget."
    exit 1
fi

# 5. Refresh Desktop
echo "🔄 Refreshing KDE Plasma Shell..."
if command -v kstart5 &>/dev/null; then
    kquitapp5 plasmashell &>/dev/null || true
    sleep 1
    kstart5 plasmashell &>/dev/null &
    disown
elif command -v plasmashell &>/dev/null; then
    plasmashell --replace >/dev/null 2>&1 &
    disown
fi

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   🎉 Done! Widget has been reinstalled!     ║"
echo "║                                            ║"
echo "║   Please delete any old widget copies on    ║"
echo "║   your desktop and drag out a fresh one    ║"
echo "║   from the KDE Widget Explorer menu.       ║"
echo "╚════════════════════════════════════════════╝"
echo ""
