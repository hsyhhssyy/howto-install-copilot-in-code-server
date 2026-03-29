#!/usr/bin/env bash
set -euo pipefail

RAW_BASE_URL="${RAW_BASE_URL:-https://raw.githubusercontent.com/hsyhhssyy/howto-install-copilot-in-code-server/refs/heads/main}"
LOCAL_SCRIPT=""

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
	SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
	if [ -f "$SCRIPT_DIR/install-code-server-extension.sh" ]; then
		LOCAL_SCRIPT="$SCRIPT_DIR/install-code-server-extension.sh"
	fi
fi

if [ -n "$LOCAL_SCRIPT" ]; then
	exec "$LOCAL_SCRIPT" openai.chatgpt
fi

curl -fsSL "$RAW_BASE_URL/install-code-server-extension.sh" | bash -s -- openai.chatgpt