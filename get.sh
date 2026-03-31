#!/bin/bash
# One-liner installer for claude-tg-reset
# Usage: curl -fsSL https://raw.githubusercontent.com/robin-li/claude-tg-reset/main/get.sh | bash
set -e

REPO="https://github.com/robin-li/claude-tg-reset.git"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "Downloading claude-tg-reset..."
git clone --depth 1 --quiet "$REPO" "$TMP_DIR"

echo ""
cd "$TMP_DIR"
bash install.sh
