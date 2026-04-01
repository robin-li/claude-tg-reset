#!/bin/bash
set -e

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.claude/scripts"
LOG_DIR="$HOME/.claude/logs"

MONITOR_PLIST_NAME="com.claude.reset-monitor"
MONITOR_PLIST_PATH="$HOME/Library/LaunchAgents/$MONITOR_PLIST_NAME.plist"

WRAPPER_PLIST_NAME="com.claude.claude-wrapper"
WRAPPER_PLIST_PATH="$HOME/Library/LaunchAgents/$WRAPPER_PLIST_NAME.plist"

STOP_FILE="$INSTALL_DIR/.stop"

echo "=== claude-tg-reset installer ==="
echo ""

# Prerequisites check
echo "[1/6] Checking prerequisites..."

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found. Please install Python 3."
    exit 1
fi

if ! command -v claude &>/dev/null; then
    echo "ERROR: claude CLI not found. Please install Claude Code first."
    exit 1
fi

if ! command -v screen &>/dev/null; then
    echo "ERROR: screen not found. Please install screen (brew install screen)."
    exit 1
fi

echo "  All prerequisites met."

# Create directories
echo "[2/6] Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"
echo "  Directories ready."

# Clean up stale state
echo "[3/6] Cleaning up stale state..."
rm -f "$STOP_FILE"
rm -f "$INSTALL_DIR/.reset"
rm -f "$INSTALL_DIR/.wrapper.pid"

# Find and kill any existing wrapper processes
EXISTING_WRAPPER=$(ps aux | grep "[c]laude-wrapper" | awk '{print $2}' | head -1)
if [ -n "$EXISTING_WRAPPER" ]; then
    echo "  Killing existing wrapper (PID $EXISTING_WRAPPER)..."
    kill -9 "$EXISTING_WRAPPER" 2>/dev/null || true
fi

# Kill any existing screen sessions
for sock in $(screen -ls 2>/dev/null | grep "claude-tg" | awk -F. '{print $1}' | awk '{print $1}'); do
    echo "  Removing screen session $sock..."
    screen -S "$sock" -X quit 2>/dev/null || true
done
echo "  Stale state cleaned."

# Install scripts
echo "[4/6] Installing scripts..."
cp "$PLUGIN_DIR/src/reset_monitor.py" "$INSTALL_DIR/reset-monitor.py"
chmod +x "$INSTALL_DIR/reset-monitor.py"
echo "  Installed: $INSTALL_DIR/reset-monitor.py"

cp "$PLUGIN_DIR/bin/claude-wrapper.sh" "$INSTALL_DIR/claude-wrapper.sh"
chmod +x "$INSTALL_DIR/claude-wrapper.sh"
echo "  Installed: $INSTALL_DIR/claude-wrapper.sh"

# Generate and install launchd plists
echo "[5/6] Setting up launchd services..."

# --- Reset monitor plist ---
cat > "$MONITOR_PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$MONITOR_PLIST_NAME</string>
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

echo "  Generated: $MONITOR_PLIST_PATH"

# --- Claude wrapper plist (uses screen to provide TTY) ---
cat > "$WRAPPER_PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$WRAPPER_PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/screen</string>
        <string>-d</string>
        <string>-m</string>
        <string>-S</string>
        <string>claude-tg</string>
        <string>$INSTALL_DIR/claude-wrapper.sh</string>
        <string>$HOME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>120</integer>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/claude-wrapper-launchd.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/claude-wrapper-launchd.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
        <key>TERM</key>
        <string>xterm-256color</string>
    </dict>
</dict>
</plist>
PLIST

echo "  Generated: $WRAPPER_PLIST_PATH"

# Load services
echo "[6/6] Starting services..."

launchctl unload "$MONITOR_PLIST_PATH" 2>/dev/null || true
launchctl load "$MONITOR_PLIST_PATH"
echo "  Reset monitor service started."

launchctl unload "$WRAPPER_PLIST_PATH" 2>/dev/null || true
launchctl load "$WRAPPER_PLIST_PATH"
echo "  Claude wrapper service started."

echo ""
echo "=== Installation complete ==="
echo ""
echo "Both services are now running and will auto-start after reboot:"
echo "  - Reset monitor: $MONITOR_PLIST_NAME"
echo "  - Claude wrapper: $WRAPPER_PLIST_NAME (via screen session 'claude-tg')"
echo ""
echo "Useful commands:"
echo "  screen -r claude-tg          # Attach to Claude session"
echo "  launchctl list | grep claude  # Check service status"
echo "  touch $STOP_FILE   # Stop wrapper gracefully"
echo ""
echo "Send one of these commands via Telegram to reset:"
echo "  #reset | reset | clear context | 清除 context | 重置 session"
echo ""
