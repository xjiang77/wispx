#!/bin/bash
# Sync CLAUDE.md → other coding agents' global config
set -euo pipefail

CLAUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$CLAUDE_DIR/CLAUDE.md"

if [ ! -f "$SOURCE" ]; then
  echo "Error: $SOURCE not found" >&2
  exit 1
fi

# Codex: ~/.codex/AGENTS.md
sync_codex() {
  local target="$HOME/.codex/AGENTS.md"
  mkdir -p "$HOME/.codex"
  {
    echo "<!-- Auto-generated from ~/.claude/CLAUDE.md by make sync -->"
    echo "<!-- Do not edit directly. Edit ~/.claude/CLAUDE.md instead. -->"
    echo ""
    cat "$SOURCE"
  } > "$target"
  echo "  ✓ Synced → $target"
}

# CodeBuddy: ~/.codebuddy/CLAUDE.md
sync_codebuddy() {
  local target="$HOME/.codebuddy/CLAUDE.md"
  mkdir -p "$HOME/.codebuddy"
  cp "$SOURCE" "$target"
  echo "  ✓ Synced → $target"
}

echo "=== Syncing from $SOURCE ==="

if [ "${1:-all}" = "codex" ] || [ "${1:-all}" = "all" ]; then
  sync_codex
fi

if [ "${1:-all}" = "codebuddy" ] || [ "${1:-all}" = "all" ]; then
  sync_codebuddy
fi

echo "Done."
