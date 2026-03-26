#!/usr/bin/env bash
# Review Agent — Installer for Claude Code
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/juandarn/review-agent/main/install-claude-code.sh | bash
#
# Options:
#   --local       Install into .claude/ in the current project (instead of global)
#   --update      Backup existing files before overwriting
#   --uninstall   Remove all review-agent files

set -euo pipefail

# --- Parse flags ---
MODE="install"
for arg in "$@"; do
  case $arg in
    --update)    MODE="update" ;;
    --uninstall) MODE="uninstall" ;;
    --local)     MODE="local" ;;
    --help|-h)
      echo "Usage: install-claude-code.sh [--local] [--update] [--uninstall]"
      echo ""
      echo "  (no flag)    Fresh global install to ~/.claude/"
      echo "  --local      Install into .claude/ in the current directory"
      echo "  --update     Backup existing agents before overwriting"
      echo "  --uninstall  Remove review-agent files"
      exit 0
      ;;
  esac
done

# --- Paths ---
REPO="https://github.com/juandarn/review-agent.git"
TMP_DIR=$(mktemp -d)
AGENT_NAMES=(review-agent frontend-reviewer backend-reviewer data-reviewer security-checker)
COMMAND_NAMES=(review)

if [ "$MODE" = "local" ]; then
  AGENTS_DIR=".claude/agents"
  COMMANDS_DIR=".claude/commands"
else
  AGENTS_DIR="${HOME}/.claude/agents"
  COMMANDS_DIR="${HOME}/.claude/commands"
fi

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# --- Uninstall ---
if [ "$MODE" = "uninstall" ]; then
  echo ""
  echo "  Uninstalling Review Agent (Claude Code)..."
  echo ""
  for name in "${AGENT_NAMES[@]}"; do
    [ -f "$AGENTS_DIR/$name.md" ] && rm -f "$AGENTS_DIR/$name.md" && echo "    Removed $AGENTS_DIR/$name.md"
  done
  for name in "${COMMAND_NAMES[@]}"; do
    [ -f "$COMMANDS_DIR/$name.md" ] && rm -f "$COMMANDS_DIR/$name.md" && echo "    Removed $COMMANDS_DIR/$name.md"
  done
  echo ""
  echo "  Done! Restart Claude Code."
  echo ""
  exit 0
fi

# --- Clone ---
echo ""
echo "  Installing Review Agent for Claude Code..."
echo ""

if ! command -v git &>/dev/null; then
  echo "  Error: git is required. Install it and try again."
  exit 1
fi

git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null

# --- Backup (update mode) ---
if [ "$MODE" = "update" ]; then
  echo "  Backing up existing files..."
  for name in "${AGENT_NAMES[@]}"; do
    if [ -f "$AGENTS_DIR/$name.md" ]; then
      cp "$AGENTS_DIR/$name.md" "$AGENTS_DIR/$name.md.bak"
      echo "    $name.md -> $name.md.bak"
    fi
  done
  for name in "${COMMAND_NAMES[@]}"; do
    if [ -f "$COMMANDS_DIR/$name.md" ]; then
      cp "$COMMANDS_DIR/$name.md" "$COMMANDS_DIR/$name.md.bak"
      echo "    $name/review.md -> review.md.bak"
    fi
  done
  echo ""
fi

# --- Copy agents ---
mkdir -p "$AGENTS_DIR"
cp "$TMP_DIR"/claude-code/agents/*.md "$AGENTS_DIR/"

# --- Copy commands ---
mkdir -p "$COMMANDS_DIR"
cp "$TMP_DIR"/claude-code/commands/*.md "$COMMANDS_DIR/"

# --- Summary ---
echo "  Agents installed to $AGENTS_DIR/"
for name in "${AGENT_NAMES[@]}"; do
  echo "    - $name.md"
done
echo ""
echo "  Commands installed to $COMMANDS_DIR/"
for name in "${COMMAND_NAMES[@]}"; do
  echo "    - $name.md"
done
echo ""
echo "  Done! Restart Claude Code."
echo ""
echo "  Usage:"
echo "    /review               Review staged changes (or last commit)"
echo "    /review PR #42        Review a pull request"
echo "    /review last commit   Review the last commit"
echo "    /review src/api/      Review a directory"
echo ""
echo "  Or select the review-agent from the agent picker."
echo ""
echo "  Prerequisites:"
echo "    - Claude Code CLI, desktop app, or IDE extension"
echo "    - gh CLI installed and authenticated (for PR reviews)"
echo ""
