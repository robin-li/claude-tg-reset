# claude-tg-reset

Remote reset Claude Code session via Telegram commands.

## Problem

When using Claude Code via the Telegram channel (CCC), there's no built-in way to clear the conversation context remotely. This plugin adds that capability.

## How It Works

1. **Reset Monitor** — A Python daemon polls your Telegram bot for reset commands
2. **Wrapper Script** — Runs Claude Code in a loop, auto-restarting after a reset
3. When you send a reset command via Telegram, the monitor kills the Claude process and the wrapper automatically restarts it with a fresh context

## Prerequisites

- macOS (launchd-based)
- Python 3
- [Claude Code](https://code.claude.com) CLI installed
- [Telegram plugin](https://github.com/anthropics/claude-code-plugins) configured with a bot token

## Installation

```bash
git clone https://github.com/anthropics/claude-tg-reset.git
cd claude-tg-reset
./install.sh
```

Or install as a Claude Code plugin:

```
/plugin install claude-tg-reset
```

Then run `install.sh` from the plugin directory to set up the launchd service.

## Usage

### Start Claude Code with auto-restart

```bash
# Default working directory (~)
~/.claude/scripts/claude-wrapper.sh

# Specify working directory
~/.claude/scripts/claude-wrapper.sh ~/workspace/my-project

# Specify model
~/.claude/scripts/claude-wrapper.sh ~/workspace --model opus
```

### Reset via Telegram

Send any of these commands to your Telegram bot:

| Command | Language |
|---------|----------|
| `#reset` | Universal |
| `reset` | English |
| `clear context` / `reset context` | English |
| `reset session` | English |
| `清除 context` / `清除context` | 中文 |
| `重置 session` / `重置session` | 中文 |

### Stop the wrapper

```bash
touch ~/.claude/scripts/.stop
```

## Uninstallation

```bash
./uninstall.sh
```

## Architecture

```
┌─────────────┐     getUpdates      ┌──────────────────┐
│  Telegram    │ ◄────────────────── │  reset-monitor.py │
│  (User)      │ ────────────────► │  (launchd daemon)  │
│              │    "#reset"         └────────┬─────────┘
└─────────────┘                              │ kill
                                             ▼
                                   ┌──────────────────┐
                                   │ claude-wrapper.sh │
                                   │   ┌────────────┐  │
                                   │   │ claude CLI  │  │ ← auto-restart
                                   │   └────────────┘  │
                                   └──────────────────┘
```

## License

MIT
