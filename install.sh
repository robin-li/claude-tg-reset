#!/bin/bash
set -e

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.claude/scripts"
LOG_DIR="$HOME/.claude/logs"
PLIST_NAME="com.claude.reset-monitor"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

echo "=== claude-tg-reset installer ==="
echo ""

# Prerequisites check
echo "[1/5] Checking prerequisites..."

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found. Please install Python 3."
    exit 1
fi

if ! command -v claude &>/dev/null; then
    echo "ERROR: claude CLI not found. Please install Claude Code first."
    exit 1
fi

if [ ! -f "$HOME/.claude/channels/telegram/.env" ]; then
    echo "ERROR: Telegram bot token not configured."
    echo "Please set up the Telegram plugin first: /telegram:configure"
    exit 1
fi

echo "  All prerequisites met."

# Create directories
echo "[2/5] Creating directories..."
mkdir -p "$INSTALL_DIR" "$LOG_DIR"

# Copy scripts
echo "[3/5] Installing scripts..."
cp "$PLUGIN_DIR/src/reset_monitor.py" "$INSTALL_DIR/reset-monitor.py"
chmod +x "$INSTALL_DIR/reset-monitor.py"
echo "  Installed: $INSTALL_DIR/reset-monitor.py"

cp "$PLUGIN_DIR/bin/claude-wrapper.sh" "$INSTALL_DIR/claude-wrapper.sh"
chmod +x "$INSTALL_DIR/claude-wrapper.sh"
echo "  Installed: $INSTALL_DIR/claude-wrapper.sh"

# Generate and install launchd plist
echo "[4/5] Setting up launchd service..."

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(command -v python3)</string>
        <string>$INSTALL_DIR/reset-monitor.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/reset-monitor.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/reset-monitor.log</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
PLIST

echo "  Generated: $PLIST_PATH"

# Load service
echo "[5/5] Starting reset monitor service..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "  Service started."

echo ""
echo "=== Installation complete ==="
echo ""
echo "Reset monitor is now running in the background."
echo "To start Claude Code with auto-restart wrapper:"
echo ""
echo "  $INSTALL_DIR/claude-wrapper.sh [working_directory] [--model MODEL]"
echo ""
echo "Then send one of these commands via Telegram to reset:"
echo "  #reset | reset | clear context | 清除 context | 重置 session"
echo ""
