#!/usr/bin/env python3
"""
Telegram Reset Monitor for Claude Code
- Polls Telegram Bot API for reset commands
- Triggers: #reset, 清除 context, 重置 session, reset, clear context, etc.
- Kills claude process (wrapper auto-restarts it)
"""

import json
import os
import signal
import subprocess
import sys
import time
import urllib.request
import urllib.error
import urllib.parse

CLAUDE_DIR = os.path.join(os.path.expanduser("~"), ".claude")
ENV_PATH = os.path.join(CLAUDE_DIR, "channels", "telegram", ".env")
ACCESS_PATH = os.path.join(CLAUDE_DIR, "channels", "telegram", "access.json")

RESET_TRIGGERS = [
    "#reset",
    "清除 context", "清除context",
    "重置 session", "重置session",
    "reset context", "clear context",
    "reset session", "reset",
]
STOP_TRIGGERS = [
    "#stop",
    "停止ccc", "停止 ccc",
    "停止claude", "停止 claude",
]
STOP_FLAG = os.path.join(CLAUDE_DIR, "scripts", ".stop")
POLL_TIMEOUT = 30


def load_bot_token():
    with open(ENV_PATH) as f:
        for line in f:
            line = line.strip()
            if line.startswith("TELEGRAM_BOT_TOKEN="):
                return line.split("=", 1)[1]
    raise RuntimeError(f"TELEGRAM_BOT_TOKEN not found in {ENV_PATH}")


def load_allowed_users():
    with open(ACCESS_PATH) as f:
        data = json.load(f)
    return set(data.get("allowFrom", []))


def tg_api(token, method, params=None):
    url = f"https://api.telegram.org/bot{token}/{method}"
    if params:
        data = urllib.parse.urlencode(params).encode()
        req = urllib.request.Request(url, data=data)
    else:
        req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=POLL_TIMEOUT + 10) as resp:
        return json.loads(resp.read().decode())


def send_message(token, chat_id, text):
    tg_api(token, "sendMessage", {"chat_id": chat_id, "text": text})


def is_reset_command(text):
    if not text:
        return False
    text_lower = text.strip().lower()
    for trigger in RESET_TRIGGERS:
        if trigger.lower() in text_lower:
            return True
    return False


def is_stop_command(text):
    if not text:
        return False
    text_lower = text.strip().lower()
    for trigger in STOP_TRIGGERS:
        if trigger.lower() in text_lower:
            return True
    return False


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
    token = load_bot_token()
    allowed_users = load_allowed_users()
    offset = 0

    print(f"[reset-monitor] Started. Allowed users: {allowed_users}")
    print(f"[reset-monitor] Triggers: {RESET_TRIGGERS}")
    sys.stdout.flush()

    while True:
        try:
            result = tg_api(token, "getUpdates", {
                "offset": offset,
                "timeout": POLL_TIMEOUT,
                "allowed_updates": "message"
            })

            if not result.get("ok"):
                print(f"[reset-monitor] API error: {result}")
                sys.stdout.flush()
                time.sleep(5)
                continue

            for update in result.get("result", []):
                offset = update["update_id"] + 1
                msg = update.get("message", {})
                text = msg.get("text", "")
                user_id = str(msg.get("from", {}).get("id", ""))
                chat_id = msg.get("chat", {}).get("id")

                if not chat_id or user_id not in allowed_users:
                    continue

                if is_stop_command(text):
                    print(f"[reset-monitor] Stop triggered by user {user_id}: {text}")
                    sys.stdout.flush()

                    send_message(token, chat_id, "正在停止 Claude Code...")

                    # Touch .stop flag so wrapper won't restart
                    os.makedirs(os.path.dirname(STOP_FLAG), exist_ok=True)
                    with open(STOP_FLAG, "a"):
                        os.utime(STOP_FLAG, None)

                    killed = kill_claude()
                    if killed:
                        send_message(token, chat_id, "Claude Code 已停止。")
                    else:
                        send_message(token, chat_id, "未找到運行中的 Claude Code 進程，已設置停止標記。")
                    continue

                if not is_reset_command(text):
                    continue

                print(f"[reset-monitor] Reset triggered by user {user_id}: {text}")
                sys.stdout.flush()

                send_message(token, chat_id, "正在重置 Claude Code session...")

                killed = kill_claude()
                if not killed:
                    send_message(token, chat_id, "未找到運行中的 Claude Code 進程。")
                    continue

                restarted = wait_for_claude_restart(timeout=30)
                if restarted:
                    send_message(token, chat_id, "Claude Code 已重啟，context 已清除。")
                else:
                    send_message(token, chat_id,
                                 "Claude Code 已終止，但尚未偵測到重啟。請確認 wrapper 是否在運行。")

        except (urllib.error.URLError, TimeoutError) as e:
            print(f"[reset-monitor] Network error: {e}")
            sys.stdout.flush()
            time.sleep(5)
        except Exception as e:
            print(f"[reset-monitor] Error: {e}")
            sys.stdout.flush()
            time.sleep(5)


if __name__ == "__main__":
    main()
