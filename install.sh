#!/usr/bin/env bash
# Review Agent — Installer for OpenCode
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/juandarn/review-agent/main/install.sh | bash
#
# Options:
#   --local       Install into .opencode/ in the current project (instead of global)
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
      echo "Usage: install.sh [--local] [--update] [--uninstall]"
      echo ""
      echo "  (no flag)    Fresh global install to ~/.config/opencode/"
      echo "  --local      Install into .opencode/ in the current directory"
      echo "  --update     Backup existing agents before overwriting"
      echo "  --uninstall  Remove review-agent files"
      exit 0
      ;;
  esac
done

# --- Paths ---
REPO="https://github.com/juandarn/review-agent.git"
TMP_DIR=$(mktemp -d)
AGENT_NAMES=(review-agent frontend-reviewer backend-reviewer security-checker)
SKILL_NAMES=(frontend-reference backend-reference)

if [ "$MODE" = "local" ]; then
  AGENTS_DIR=".opencode/agents"
  SKILLS_DIR=".opencode/skills"
else
  AGENTS_DIR="${HOME}/.config/opencode/agents"
  SKILLS_DIR="${HOME}/.config/opencode/skills"
fi

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# --- Uninstall ---
if [ "$MODE" = "uninstall" ]; then
  echo ""
  echo "  Uninstalling Review Agent..."
  echo ""
  for name in "${AGENT_NAMES[@]}"; do
    [ -f "$AGENTS_DIR/$name.md" ] && rm -f "$AGENTS_DIR/$name.md" && echo "    Removed $AGENTS_DIR/$name.md"
  done
  for name in "${SKILL_NAMES[@]}"; do
    [ -d "$SKILLS_DIR/$name" ] && rm -rf "$SKILLS_DIR/$name" && echo "    Removed $SKILLS_DIR/$name/"
  done
  echo ""
  echo "  Done! Restart OpenCode."
  echo ""
  exit 0
fi

# --- Clone ---
echo ""
echo "  Installing Review Agent for OpenCode..."
echo ""

if ! command -v git &>/dev/null; then
  echo "  Error: git is required. Install it and try again."
  exit 1
fi

git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null

# --- Backup (update mode) ---
if [ "$MODE" = "update" ]; then
  echo "  Backing up existing agents..."
  for name in "${AGENT_NAMES[@]}"; do
    if [ -f "$AGENTS_DIR/$name.md" ]; then
      cp "$AGENTS_DIR/$name.md" "$AGENTS_DIR/$name.md.bak"
      echo "    $name.md -> $name.md.bak"
    fi
  done
  for name in "${SKILL_NAMES[@]}"; do
    if [ -f "$SKILLS_DIR/$name/SKILL.md" ]; then
      cp "$SKILLS_DIR/$name/SKILL.md" "$SKILLS_DIR/$name/SKILL.md.bak"
      echo "    $name/SKILL.md -> $name/SKILL.md.bak"
    fi
  done
  echo ""
fi

# --- Copy agents ---
mkdir -p "$AGENTS_DIR"
cp "$TMP_DIR"/agents/*.md "$AGENTS_DIR/"

# --- Copy skills ---
for name in "${SKILL_NAMES[@]}"; do
  mkdir -p "$SKILLS_DIR/$name"
  cp "$TMP_DIR/skills/$name/SKILL.md" "$SKILLS_DIR/$name/SKILL.md"
done

# --- Summary ---
echo "  Agents installed to $AGENTS_DIR/"
for name in "${AGENT_NAMES[@]}"; do
  echo "    - $name.md"
done
echo ""
echo "  Skills installed to $SKILLS_DIR/"
for name in "${SKILL_NAMES[@]}"; do
  echo "    - $name/"
done
echo ""
echo "  Done! Restart OpenCode and press Tab."
echo ""
echo "  Usage:"
echo "    review-agent    Review commits, staged changes, dirs, or PRs"
echo ""
echo "  Examples:"
echo "    'review last commit'"
echo "    'review staged changes'"
echo "    'review PR #42'"
echo "    'review src/api/'"
echo ""
echo "  Prerequisites:"
echo "    - LLM provider configured in OpenCode (uses your selected model)"
echo "    - gh CLI installed (for PR reviews)"
echo ""
