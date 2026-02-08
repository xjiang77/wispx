#!/bin/bash
# Notify when Claude is waiting for input (macOS notification)
MESSAGE=$(cat | jq -r '.message // "Claude needs your attention"')
osascript -e "display notification \"$MESSAGE\" with title \"Claude Code\""
exit 0
