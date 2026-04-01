#!/bin/bash
#
# Claude Code auto-restart wrapper
# Usage: claude-wrapper.sh [working_directory] [--model MODEL]
#
# Stop gracefully: touch ~/.claude/scripts/.stop
# Resume: rm ~/.claude/scripts/.stop && run this script again

CLAUDE_BIN="$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")"
STOP_FILE="$HOME/.claude/scripts/.stop"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/claude-wrapper.log"
SESSION_NAME="claude-tg"

WORK_DIR="$HOME"
MODEL="sonnet"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            MODEL="$2"
            shift 2
            ;;
        *)
            WORK_DIR="$1"
            shift
            ;;
    esac
done

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

rm -f "$STOP_FILE"

# Prevent multiple wrapper instances (only needed when NOT inside screen)
if [ -z "$STY" ]; then
    # We're NOT in screen yet - check if a session already exists
    EXISTING=$(screen -ls 2>/dev/null | grep "$SESSION_NAME" | awk -F. '{print $1}' | awk '{print $1}' | head -1)
    if [ -n "$EXISTING" ]; then
        echo "Session $SESSION_NAME already exists (PID $EXISTING), skipping duplicate start"
        exit 0
    fi
fi

log "Wrapper started. Working directory: $WORK_DIR, Model: $MODEL"
log "Claude binary: $CLAUDE_BIN"
log "To stop: touch $STOP_FILE"

while true; do
    if [ -f "$STOP_FILE" ]; then
        log "Stop file detected. Exiting wrapper."
        exit 0
    fi

    log "Starting Claude Code..."
    cd "$WORK_DIR" || exit 1

    "$CLAUDE_BIN" \
        --dangerously-skip-permissions \
        --channels plugin:telegram@claude-plugins-official \
        --model "$MODEL"

    EXIT_CODE=$?
    log "Claude Code exited with code $EXIT_CODE"

    if [ -f "$STOP_FILE" ]; then
        log "Stop file detected after exit. Exiting wrapper."
        exit 0
    fi

    log "Restarting in 3 seconds..."
    sleep 3
done
