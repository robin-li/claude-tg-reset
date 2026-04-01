#!/bin/bash
set -e

INSTALL_DIR="$HOME/.claude/scripts"
MONITOR_PLIST_NAME="com.claude.reset-monitor"
MONITOR_PLIST_PATH="$HOME/Library/LaunchAgents/$MONITOR_PLIST_NAME.plist"
WRAPPER_PLIST_NAME="com.claude.claude-wrapper"
WRAPPER_PLIST_PATH="$HOME/Library/LaunchAgents/$WRAPPER_PLIST_NAME.plist"

echo "=== claude-tg-reset uninstaller ==="
echo ""

# Stop services
echo "[1/3] Stopping services..."
for PLIST_PATH in "$MONITOR_PLIST_PATH" "$WRAPPER_PLIST_PATH"; do
    if [ -f "$PLIST_PATH" ]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        echo "  Stopped and removed: $PLIST_PATH"
    fi
done

# Kill any lingering screen session
screen -S claude-tg -X quit 2>/dev/null || true

# Remove scripts
echo "[2/3] Removing scripts..."
for f in reset-monitor.py claude-wrapper.sh; do
    if [ -f "$INSTALL_DIR/$f" ]; then
        rm -f "$INSTALL_DIR/$f"
        echo "  Removed: $INSTALL_DIR/$f"
    fi
done

# Remove stop file if exists
rm -f "$INSTALL_DIR/.stop"

# Clean up empty directory
echo "[3/3] Cleaning up..."
if [ -d "$INSTALL_DIR" ] && [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
    rmdir "$INSTALL_DIR"
    echo "  Removed empty directory: $INSTALL_DIR"
else
    echo "  $INSTALL_DIR has other files, kept."
fi

echo ""
echo "=== Uninstallation complete ==="
echo ""
