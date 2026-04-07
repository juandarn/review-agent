#!/usr/bin/env bash
# Review Agent — Installer for Claude Code
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/juandarn/review-agent/main/install-claude-code.sh | bash
#
# Options:
#   --local        Install into .claude/ in the current project (instead of global)
#   --update       Backup existing files before overwriting
#   --uninstall    Remove all review-agent files
#   --with-hooks   Also install the pre-push git hook
#   --with-config  Copy .review-agent.example.yml to current directory

set -euo pipefail

# --- Parse flags ---
MODE="install"
WITH_HOOKS=false
WITH_CONFIG=false
for arg in "$@"; do
  case $arg in
    --update)      MODE="update" ;;
    --uninstall)   MODE="uninstall" ;;
    --local)       MODE="local" ;;
    --with-hooks)  WITH_HOOKS=true ;;
    --with-config) WITH_CONFIG=true ;;
    --help|-h)
      echo "Usage: install-claude-code.sh [--local] [--update] [--uninstall] [--with-hooks] [--with-config]"
      echo ""
      echo "  (no flag)      Fresh global install to ~/.claude/"
      echo "  --local        Install into .claude/ in the current directory"
      echo "  --update       Backup existing agents before overwriting"
      echo "  --uninstall    Remove review-agent files"
      echo "  --with-hooks   Install pre-push git hook for automatic quick review"
      echo "  --with-config  Copy .review-agent.example.yml to current directory"
      exit 0
      ;;
  esac
done

# --- Paths ---
REPO="https://github.com/juandarn/review-agent.git"
TMP_DIR=$(mktemp -d)
AGENT_NAMES=(
  review-agent frontend-reviewer backend-reviewer data-reviewer security-checker
  refactor-agent refactor-analyzer
  arch-agent frontend-arch-analyzer backend-arch-analyzer
  agents-doc-generator codebase-mapper flow-tracer
  research-agent theory-analyzer implementation-planner
)
COMMAND_NAMES=(cr cr-refactor cr-arch cr-agents cr-research)

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
  # Also remove old /review command if it exists
  [ -f "$COMMANDS_DIR/review.md" ] && rm -f "$COMMANDS_DIR/review.md" && echo "    Removed $COMMANDS_DIR/review.md (legacy)"
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
      echo "    $name.md -> $name.md.bak"
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

# --- Remove legacy /review command if exists ---
[ -f "$COMMANDS_DIR/review.md" ] && rm -f "$COMMANDS_DIR/review.md"

# --- Install hooks (optional) ---
if [ "$WITH_HOOKS" = true ]; then
  if [ -d ".git" ]; then
    bash "$TMP_DIR/hooks/install-hook.sh"
  else
    echo "  Skipping hook install: not a git repository."
  fi
fi

# --- Copy config template (optional) ---
if [ "$WITH_CONFIG" = true ]; then
  if [ ! -f ".review-agent.yml" ]; then
    cp "$TMP_DIR/.review-agent.example.yml" ".review-agent.yml"
    echo "  Copied .review-agent.yml to current directory."
  else
    echo "  .review-agent.yml already exists, skipping."
  fi
fi

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
echo "  Commands:"
echo "    /cr                    Code review (modes: deep, quick, security-only, etc.)"
echo "    /cr-refactor           Analyze code smells and suggest refactorings"
echo "    /cr-arch               Analyze architecture (frontend/backend separately)"
echo "    /cr-agents             Generate AGENTS.md for the project"
echo "    /cr-research           Research how to integrate new features"
echo ""
echo "  Examples:"
echo "    /cr quick staged changes"
echo "    /cr security-only PR #42"
echo "    /cr-refactor src/api/"
echo "    /cr-arch generate"
echo "    /cr-agents"
echo "    /cr-agents update"
echo "    /cr-research add OAuth2 authentication"
echo ""
echo "  Or select any agent from the agent picker."
echo ""
echo "  Prerequisites:"
echo "    - Claude Code CLI, desktop app, or IDE extension"
echo "    - gh CLI installed and authenticated (for PR reviews)"
echo ""
