#!/usr/bin/env bash
# Review Agent — Installer for OpenCode
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/juandarn/review-agent/main/install.sh | bash
#
# Options:
#   --local        Install into .opencode/ in the current project (instead of global)
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
      echo "Usage: install.sh [--local] [--update] [--uninstall] [--with-hooks] [--with-config]"
      echo ""
      echo "  (no flag)      Fresh global install to ~/.config/opencode/"
      echo "  --local        Install into .opencode/ in the current directory"
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
SKILL_NAMES=(frontend-reference backend-reference data-reference refactoring-patterns architecture-patterns)

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
echo "  Skills installed to $SKILLS_DIR/"
for name in "${SKILL_NAMES[@]}"; do
  echo "    - $name/"
done
echo ""
echo "  Done! Restart OpenCode and press Tab."
echo ""
echo "  Commands (via agents):"
echo "    review-agent          Code review (modes: deep, quick, security-only, etc.)"
echo "    refactor-agent        Analyze code smells and suggest refactorings"
echo "    arch-agent            Analyze architecture (frontend/backend separately)"
echo "    agents-doc-generator  Generate AGENTS.md for the project"
echo "    research-agent        Research how to integrate new features"
echo ""
echo "  Examples:"
echo "    'review quick staged changes'"
echo "    'review security-only PR #42'"
echo "    'refactor src/api/'"
echo "    'analyze architecture'"
echo "    'generate AGENTS.md'"
echo "    'research adding OAuth2 authentication'"
echo ""
echo "  Prerequisites:"
echo "    - LLM provider configured in OpenCode (uses your selected model)"
echo "    - gh CLI installed (for PR reviews)"
echo ""
