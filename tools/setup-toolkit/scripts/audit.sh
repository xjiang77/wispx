#!/bin/bash
# Audit global config against best practices
set -euo pipefail

PASS=0; WARN=0
CLAUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
warn() { echo "  ⚠ $1"; WARN=$((WARN + 1)); }

echo "=== CLAUDE.md Audit ==="
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  lines=$(wc -l < "$CLAUDE_DIR/CLAUDE.md" | tr -d ' ')
  tokens_est=$((lines * 15))
  if [ "$lines" -le 50 ]; then
    pass "$lines lines (~${tokens_est} tokens)"
  else
    warn "$lines lines (~${tokens_est} tokens) — recommend ≤50 lines"
  fi

  # Anti-patterns
  for pattern in "you are" "step by step" "be careful" "please always" "remember to"; do
    if grep -qi "$pattern" "$CLAUDE_DIR/CLAUDE.md"; then
      warn "Found anti-pattern: \"$pattern\" (wastes tokens, agent already does this)"
    else
      pass "No anti-pattern: \"$pattern\""
    fi
  done
fi

echo ""
echo "=== settings.json Audit ==="
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  # Required deny patterns
  required_deny=("rm -rf" "sudo" "git push --force" "git push -f" "git reset --hard")
  for pattern in "${required_deny[@]}"; do
    if jq -e ".permissions.deny[] | select(contains(\"$pattern\"))" "$CLAUDE_DIR/settings.json" &>/dev/null; then
      pass "Deny: \"$pattern\""
    else
      warn "Missing deny: \"$pattern\""
    fi
  done

  # Hook check
  if jq -e '.hooks.PreToolUse | length > 0' "$CLAUDE_DIR/settings.json" &>/dev/null; then
    pass "PreToolUse hook configured"
  else
    warn "No PreToolUse safety hook"
  fi

  # Hardcoded path check: warn only if path belongs to a different user
  other_user_paths=$(grep -oE '/Users/[^/]+/' "$CLAUDE_DIR/settings.json" | grep -v "$HOME/" || true)
  if [ -n "$other_user_paths" ]; then
    warn "Hardcoded path for another user found — run 'make install' to fix"
  else
    pass "No foreign hardcoded home paths"
  fi

  # Allow list size
  allow_count=$(jq '.permissions.allow | length' "$CLAUDE_DIR/settings.json")
  pass "Allow list: $allow_count rules"
  deny_count=$(jq '.permissions.deny | length' "$CLAUDE_DIR/settings.json")
  pass "Deny list: $deny_count rules"
fi

echo ""
echo "=== Hooks Audit ==="
hook_count=0
for hook in "$CLAUDE_DIR"/hooks/*.sh; do
  [ -f "$hook" ] || continue
  hook_count=$((hook_count + 1))
  name=$(basename "$hook")
  lines=$(wc -l < "$hook" | tr -d ' ')
  if [ "$lines" -le 50 ]; then
    pass "$name: $lines lines"
  else
    warn "$name: $lines lines (recommend ≤50)"
  fi
done
pass "Total hooks: $hook_count"

echo ""
echo "=== Skills Audit ==="
skill_count=0
for skill_dir in "$CLAUDE_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    # Check frontmatter
    if head -1 "$skill_dir/SKILL.md" | grep -q "^---"; then
      pass "$skill_name: valid SKILL.md with frontmatter"
    else
      warn "$skill_name: SKILL.md missing YAML frontmatter"
    fi
    skill_count=$((skill_count + 1))
  else
    warn "$skill_name: missing SKILL.md"
  fi
done
pass "Total skills: $skill_count"

echo ""
echo "=== Summary ==="
echo "  $PASS passed, $WARN warnings"
[ "$WARN" -eq 0 ] && exit 0 || exit 1
