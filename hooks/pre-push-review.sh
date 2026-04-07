#!/usr/bin/env bash
# pre-push hook — runs a quick code review before push
#
# This hook is NON-BLOCKING: it always exits 0, so your push will never
# be prevented. It simply shows warnings if issues are found.
#
# Install:
#   cp hooks/pre-push-review.sh .git/hooks/pre-push
#   chmod +x .git/hooks/pre-push
#
# Or use: bash install.sh --with-hooks / bash install-claude-code.sh --with-hooks

set -euo pipefail

# Get the diff between what's being pushed and what's on remote
DIFF=$(git diff @{push}..HEAD 2>/dev/null || git diff origin/main..HEAD 2>/dev/null || git diff HEAD~1 HEAD 2>/dev/null)

# Skip if no diff
if [ -z "$DIFF" ]; then
  exit 0
fi

# Count changed files
FILES_CHANGED=$(echo "$DIFF" | grep -c "^diff --git" || true)

echo ""
echo "  Running quick code review before push ($FILES_CHANGED files changed)..."
echo ""

# Try Claude Code CLI first, then OpenCode
if command -v claude &>/dev/null; then
  echo "review quick the following diff:
$DIFF" | claude --print 2>/dev/null || true
elif command -v opencode &>/dev/null; then
  echo "  Note: Automatic review requires Claude Code CLI (claude --print)."
  echo "  Run '/cr quick' manually before pushing."
fi

echo ""

# Always allow push
exit 0
