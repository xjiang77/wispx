#!/bin/bash
# Block edits to sensitive files
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')

PROTECTED_PATTERNS=(
  ".env"
  ".env.*"
  "*.pem"
  "*.key"
  "*credentials*"
  "*secret*"
)

BASENAME=$(basename "$FILE_PATH")
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  # shellcheck disable=SC2254
  case "$BASENAME" in
    $pattern)
      echo "Blocked: $FILE_PATH matches protected pattern '$pattern'" >&2
      exit 2
      ;;
  esac
done

exit 0
