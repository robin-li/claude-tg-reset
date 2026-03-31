#!/usr/bin/env python3
"""
File-based Reset Monitor for Claude Code
- Watches for signal files to trigger reset/stop
- Reset: touch ~/.claude/scripts/.reset
- Stop:  touch ~/.claude/scripts/.stop
- Avoids polling Telegram (prevents message loss from competing getUpdates)
"""

import os
import signal
import subprocess
import sys
import time

CLAUDE_DIR = os.path.join(os.path.expanduser("~"), ".claude")
SCRIPTS_DIR = os.path.join(CLAUDE_DIR, "scripts")
RESET_FLAG = os.path.join(SCRIPTS_DIR, ".reset")
STOP_FLAG = os.path.join(SCRIPTS_DIR, ".stop")
POLL_INTERVAL = 2


def log(msg):
    print(f"[reset-monitor] {msg}")
    sys.stdout.flush()


def find_claude_pids():
    """Find claude CLI processes (the ones with --channels plugin:telegram)."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", "claude.*--channels.*plugin:telegram"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            return [int(pid) for pid in result.stdout.strip().split("\n") if pid]
    except Exception:
        pass

    # Fallback: find claude --dangerously-skip-permissions
    try:
        result = subprocess.run(
            ["pgrep", "-f", "claude.*--dangerously-skip-permissions"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            my_pid = os.getpid()
            return [int(pid) for pid in result.stdout.strip().split("\n")
                    if pid and int(pid) != my_pid]
    except Exception:
        pass

    return []


def kill_claude():
    """Kill claude processes and return True if any were killed."""
    pids = find_claude_pids()
    if not pids:
        return False

    for pid in pids:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

    time.sleep(2)
    for pid in pids:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    return True


def wait_for_claude_restart(timeout=30):
    """Wait for claude process to come back (wrapper restarts it)."""
    start = time.time()
    while time.time() - start < timeout:
        if find_claude_pids():
            return True
        time.sleep(2)
    return False


def main():
    os.makedirs(SCRIPTS_DIR, exist_ok=True)

    log("Started (file-based mode)")
    log(f"  Reset signal: touch {RESET_FLAG}")
    log(f"  Stop signal:  touch {STOP_FLAG}")

    while True:
        # Check stop signal
        if os.path.exists(STOP_FLAG):
            log("Stop signal detected.")
            killed = kill_claude()
            if killed:
                log("Claude Code stopped.")
            else:
                log("No running Claude Code process found. Stop flag preserved.")
            # Don't remove .stop — wrapper checks it too
            break

        # Check reset signal
        if os.path.exists(RESET_FLAG):
            log("Reset signal detected.")
            try:
                os.remove(RESET_FLAG)
            except OSError:
                pass

            killed = kill_claude()
            if not killed:
                log("No running Claude Code process found.")
            else:
                log("Claude Code killed. Waiting for wrapper to restart...")
                restarted = wait_for_claude_restart(timeout=30)
                if restarted:
                    log("Claude Code restarted successfully.")
                else:
                    log("Claude Code not detected after 30s. Check wrapper.")

        time.sleep(POLL_INTERVAL)

    log("Monitor exiting.")


if __name__ == "__main__":
    main()
