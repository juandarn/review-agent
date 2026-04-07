#!/usr/bin/env bash
# Install the pre-push review hook into the current git repository
#
# Usage:
#   bash hooks/install-hook.sh
#   bash hooks/install-hook.sh --uninstall

set -euo pipefail

HOOK_FILE=".git/hooks/pre-push"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_HOOK="$SCRIPT_DIR/pre-push-review.sh"

# Check we're in a git repo
if [ ! -d ".git" ]; then
  echo "  Error: Not a git repository. Run this from your project root."
  exit 1
fi

# Uninstall
if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$HOOK_FILE" ] && grep -q "quick code review" "$HOOK_FILE" 2>/dev/null; then
    rm -f "$HOOK_FILE"
    echo "  Removed pre-push review hook."
  else
    echo "  No review hook found."
  fi
  exit 0
fi

# Check for existing hook
if [ -f "$HOOK_FILE" ]; then
  if grep -q "quick code review" "$HOOK_FILE" 2>/dev/null; then
    echo "  Review hook already installed. Use --uninstall to remove first."
    exit 0
  else
    echo "  Warning: A pre-push hook already exists."
    echo "  Backing up to $HOOK_FILE.bak"
    cp "$HOOK_FILE" "$HOOK_FILE.bak"
  fi
fi

# Install
mkdir -p .git/hooks
cp "$SOURCE_HOOK" "$HOOK_FILE"
chmod +x "$HOOK_FILE"

echo ""
echo "  Pre-push review hook installed!"
echo "  Every push will run a quick code review (non-blocking)."
echo ""
echo "  To uninstall: bash hooks/install-hook.sh --uninstall"
echo ""
