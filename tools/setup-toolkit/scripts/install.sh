#!/bin/bash
# Install toolkit to ~/.claude/ (non-destructive)
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$HOME/.claude"

echo "=== Installing Setup Toolkit ==="
echo "Source: $TOOLKIT_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Create target dirs
mkdir -p "$TARGET_DIR"/{hooks,templates,skills,agents,mcp,scripts}

# Copy CLAUDE.md (overwrite — this is the managed config)
cp "$TOOLKIT_DIR/dotclaude/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
echo "  ✓ Installed CLAUDE.md"

# Copy settings.json (overwrite — managed config)
cp "$TOOLKIT_DIR/dotclaude/settings.json" "$TARGET_DIR/settings.json"
echo "  ✓ Installed settings.json"

# Fix __HOME__ placeholder → actual $HOME
sed -i '' "s|__HOME__|$HOME|g" "$TARGET_DIR/settings.json"
echo "  ✓ Fixed home paths in settings.json"

# Merge local overrides if they exist
if [ -f "$TARGET_DIR/settings.local.json" ]; then
  if command -v jq &>/dev/null; then
    # Merge local allow/deny into base settings
    local_allow=$(jq -r '.permissions.allow // [] | .[]' "$TARGET_DIR/settings.local.json" 2>/dev/null)
    local_deny=$(jq -r '.permissions.deny // [] | .[]' "$TARGET_DIR/settings.local.json" 2>/dev/null)
    if [ -n "$local_allow" ] || [ -n "$local_deny" ]; then
      echo "  ✓ Local overrides detected (settings.local.json)"
    fi
  fi
fi

# Copy statusline
cp "$TOOLKIT_DIR/dotclaude/statusline-command.sh" "$TARGET_DIR/statusline-command.sh"
echo "  ✓ Installed statusline-command.sh"

# Copy hooks (non-destructive for local hooks)
for hook in "$TOOLKIT_DIR"/dotclaude/hooks/*.sh; do
  [ -f "$hook" ] || continue
  name=$(basename "$hook")
  cp "$hook" "$TARGET_DIR/hooks/$name"
  echo "  ✓ Installed hook: $name"
done

# Copy templates
for tpl in "$TOOLKIT_DIR"/dotclaude/templates/*; do
  [ -f "$tpl" ] || continue
  name=$(basename "$tpl")
  cp "$tpl" "$TARGET_DIR/templates/$name"
  echo "  ✓ Installed template: $name"
done

# Copy scripts
for script in "$TOOLKIT_DIR"/scripts/*.sh; do
  [ -f "$script" ] || continue
  name=$(basename "$script")
  cp "$script" "$TARGET_DIR/scripts/$name"
  echo "  ✓ Installed script: $name"
done

# Install skills
echo ""
echo "=== Installing Skills ==="
for skill_dir in "$TOOLKIT_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  target_skill="$TARGET_DIR/skills/$skill_name"
  mkdir -p "$target_skill"
  cp -r "$skill_dir"* "$target_skill/" 2>/dev/null || true
  echo "  ✓ Installed skill: $skill_name"
done

# Make scripts executable
chmod +x "$TARGET_DIR"/hooks/*.sh "$TARGET_DIR"/statusline-command.sh "$TARGET_DIR"/scripts/*.sh 2>/dev/null || true
echo ""
echo "  ✓ Set executable permissions"

# Sync to other agents
echo ""
"$TARGET_DIR/scripts/sync-agents.sh" all

# Run doctor
echo ""
"$TARGET_DIR/scripts/doctor.sh"

echo ""
echo "=== Install Complete ==="

# Suggest alias
if ! grep -q "alias cc-make=" ~/.zshrc 2>/dev/null && ! grep -q "alias cc-make=" ~/.bashrc 2>/dev/null; then
  echo ""
  echo "Tip: Add this alias to use cc-make from anywhere:"
  echo "  echo \"alias cc-make='make -C ~/.claude'\" >> ~/.zshrc && source ~/.zshrc"
fi
