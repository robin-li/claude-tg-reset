---
name: tg-reset
description: Show installation status and usage guide for the Telegram remote reset feature. Use when user asks about resetting Claude Code via Telegram.
argument-hint: [status|help]
allowed-tools: [Bash, Read]
---

# Telegram Remote Reset for Claude Code

Check installation status and provide usage guidance for the `claude-tg-reset` plugin.

## What to do

1. Check if the reset monitor is running:
   ```bash
   launchctl list | grep com.claude.reset-monitor
   ```

2. Check if the wrapper is running:
   ```bash
   pgrep -f "claude.*--channels.*plugin:telegram"
   ```

3. Report status and show available commands:
   - Telegram reset commands: `#reset`, `清除 context`, `重置 session`, `reset context`, `clear context`, `reset session`, `reset`
   - Telegram stop commands: `#stop`, `停止ccc`, `停止claude`
   - Manual signal files: `touch ~/.claude/scripts/.reset` (reset) / `touch ~/.claude/scripts/.stop` (stop)

4. If not installed, guide the user to run `install.sh` from the plugin directory.
