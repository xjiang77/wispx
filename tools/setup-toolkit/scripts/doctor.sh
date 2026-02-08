#!/bin/bash
# Diagnose common issues with coding agent setup
set -euo pipefail

PASS=0; WARN=0; FAIL=0
CLAUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
warn() { echo "  ⚠ $1"; WARN=$((WARN + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== CLI Tools ==="
for cmd in claude jq git; do
  command -v "$cmd" &>/dev/null && pass "$cmd installed" || fail "$cmd not found"
done
for cmd in codex codebuddy; do
  command -v "$cmd" &>/dev/null && pass "$cmd installed (optional)" || warn "$cmd not found (optional)"
done

echo ""
echo "=== Config Files ==="
[ -f "$CLAUDE_DIR/CLAUDE.md" ] && pass "CLAUDE.md exists" || fail "CLAUDE.md missing"
[ -f "$CLAUDE_DIR/settings.json" ] && pass "settings.json exists" || fail "settings.json missing"

if [ -f "$CLAUDE_DIR/settings.json" ]; then
  jq empty "$CLAUDE_DIR/settings.json" 2>/dev/null && pass "settings.json is valid JSON" || fail "settings.json is invalid JSON"
fi

echo ""
echo "=== Hooks ==="
for hook in "$CLAUDE_DIR"/hooks/*.sh; do
  [ -f "$hook" ] || continue
  name=$(basename "$hook")
  [ -x "$hook" ] && pass "$name is executable" || fail "$name is not executable"
done

if [ -f "$CLAUDE_DIR/settings.json" ]; then
  if jq -e '.hooks.PreToolUse' "$CLAUDE_DIR/settings.json" &>/dev/null; then
    pass "PreToolUse hook configured"
  else
    warn "No PreToolUse hook (safety gate)"
  fi
fi

echo ""
echo "=== Safety ==="
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  for pattern in "rm -rf" "sudo" "git push --force"; do
    if jq -e ".permissions.deny[] | select(contains(\"$pattern\"))" "$CLAUDE_DIR/settings.json" &>/dev/null; then
      pass "\"$pattern\" is denied"
    else
      warn "\"$pattern\" not in deny list"
    fi
  done
fi

echo ""
echo "=== Context Budget ==="
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  lines=$(wc -l < "$CLAUDE_DIR/CLAUDE.md" | tr -d ' ')
  if [ "$lines" -le 50 ]; then
    pass "CLAUDE.md is $lines lines (≤50)"
  else
    warn "CLAUDE.md is $lines lines (>50, may waste context)"
  fi
fi

echo ""
echo "=== Summary ==="
echo "  $PASS passed, $WARN warnings, $FAIL failures"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
