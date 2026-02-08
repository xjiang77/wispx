#!/bin/bash
# Initialize project-level coding agent config
set -euo pipefail

CLAUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${1:?Usage: init-project.sh <project-path>}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

echo "Initializing coding agent config for: $PROJECT_NAME"
echo "Path: $PROJECT_DIR"
echo ""

# CLAUDE.md (Claude Code + CodeBuddy)
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$CLAUDE_DIR/templates/CLAUDE.md.tpl" > "$PROJECT_DIR/CLAUDE.md"
  echo "  ✓ Created CLAUDE.md"
else
  echo "  - CLAUDE.md already exists, skipping"
fi

# AGENTS.md (Codex)
if [ ! -f "$PROJECT_DIR/AGENTS.md" ]; then
  sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$CLAUDE_DIR/templates/AGENTS.md.tpl" > "$PROJECT_DIR/AGENTS.md"
  echo "  ✓ Created AGENTS.md"
else
  echo "  - AGENTS.md already exists, skipping"
fi

# .claude/settings.local.json
if [ ! -d "$PROJECT_DIR/.claude" ]; then
  mkdir -p "$PROJECT_DIR/.claude"
  cp "$CLAUDE_DIR/templates/settings.local.json.tpl" "$PROJECT_DIR/.claude/settings.local.json"
  echo "  ✓ Created .claude/settings.local.json"
else
  echo "  - .claude/ already exists, skipping"
fi

echo ""
echo "Done. Edit the generated files to match your project."
