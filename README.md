# review-agent

A code analysis suite for [OpenCode](https://opencode.ai) and [Claude Code](https://claude.ai/claude-code). Reviews code, analyzes refactoring opportunities, evaluates architecture, generates AI agent guides, and researches feature integration — all with contextual design principle assessment.

Auto-detects frontend (React/TS), backend (Go/Python), and data (dbt/SQL) stacks, delegating to specialized subagents for deep analysis.

---

## The `/cr-*` Suite

| Command | What it does |
|---------|-------------|
| `/cr` | Code review — commits, staged changes, PRs. Modes: deep, quick, security-only, etc. |
| `/cr-refactor` | Analyze code smells, complexity, duplication. Suggests concrete refactorings. |
| `/cr-arch` | Architecture analysis — frontend/backend separately. Can generate `ARCHITECTURE.md`. |
| `/cr-agents` | Generate `AGENTS.md` — full context for AI agents to work in the project. |
| `/cr-research` | Research feature integration — theoretical analysis + implementation plan. |

All commands support project-specific customization via `.review-agent.yml`.

---

## Quick Install

### OpenCode

```bash
curl -fsSL https://raw.githubusercontent.com/juandarn/review-agent/main/install.sh | bash
```

### Claude Code

```bash
curl -fsSL https://raw.githubusercontent.com/juandarn/review-agent/main/install-claude-code.sh | bash
```

### Install options

```bash
# Install for current project only
bash install.sh --local
bash install-claude-code.sh --local

# Update existing install (backs up current files)
bash install.sh --update

# With pre-push hook (auto quick review before push)
bash install-claude-code.sh --with-hooks

# With project config template
bash install-claude-code.sh --with-config

# Uninstall
bash install.sh --uninstall
bash install-claude-code.sh --uninstall
```

<details>
<summary>Manual install (Claude Code)</summary>

```bash
git clone https://github.com/juandarn/review-agent.git /tmp/review-agent \
  && mkdir -p ~/.claude/agents ~/.claude/commands \
  && cp /tmp/review-agent/claude-code/agents/*.md ~/.claude/agents/ \
  && cp /tmp/review-agent/claude-code/commands/*.md ~/.claude/commands/ \
  && rm -rf /tmp/review-agent \
  && echo "Done! Restart Claude Code."
```
</details>

---

## Prerequisites

- [OpenCode](https://opencode.ai) or [Claude Code](https://claude.ai/claude-code)
- `gh` CLI installed and authenticated (for PR reviews)

---

## `/cr` — Code Review

### Modes

| Mode | What runs | Output |
|------|-----------|--------|
| `deep` (default) | All detected stacks + security | Full report |
| `quick` | All detected stacks + security | Only Must Fix + Verdict |
| `security-only` | Security checker | Security report only |
| `frontend-only` | Frontend reviewer | Frontend report only |
| `backend-only` | Backend reviewer | Backend report only |
| `data-only` | Data reviewer | Data report only |

### Examples

```
/cr                           # Review staged changes (deep mode)
/cr quick PR #42              # Quick review of PR
/cr security-only last commit # Security-only review
/cr deep HEAD~3..HEAD         # Deep review of last 3 commits
/cr frontend-only src/components/
```

### What it checks

**Frontend**: React hooks, TypeScript, performance, accessibility, component design, styling
**Backend**: Go error handling/concurrency, Python type hints/async, API design, SQL safety
**Data**: dbt patterns, SQL window functions, JSON handling, warehouse specifics, data quality
**Security**: OWASP Top 10, secrets, injection, auth, input validation, dependencies

### Contextual principles

Before reviewing, the agent assesses the project (size, type, maturity) and selects
appropriate design principles (SOLID, KISS, YAGNI, DDD, etc.) — then asks you to confirm.
A small script gets KISS/YAGNI; a large enterprise app gets full SOLID + Clean Architecture.

---

## `/cr-refactor` — Refactoring Analysis

Analyzes code for smells and suggests concrete refactorings, categorized by impact.

```
/cr-refactor src/api/handlers/    # Analyze a directory
/cr-refactor src/components/Form.tsx  # Analyze a file
/cr-refactor staged changes       # Analyze staged files (full context)
```

**Detects**: Extract Function, God Class, Cyclomatic Complexity, DRY violations,
design principle violations (SRP, DIP, ISP), circular dependencies, dead code, and more.

**Output**: High/Medium/Low impact tables + Code Health Score (Complexity, DRY, Principles, Readability).

---

## `/cr-arch` — Architecture Analysis

Evaluates codebase architecture with **separate frontend and backend analysis**.

```
/cr-arch                # Analyze entire project
/cr-arch src/           # Analyze specific directory
/cr-arch generate       # Analyze + generate ARCHITECTURE.md with Mermaid diagrams
```

**Frontend analysis**: Component tree, state management, routing, styling, organization pattern
**Backend analysis**: Layer architecture, domain model, API design, DB patterns, DI

**Output**: Patterns detected, Mermaid dependency diagrams, coupling analysis (fan-in/fan-out),
principles assessment, prioritized recommendations, Health Score.

---

## `/cr-agents` — Generate AGENTS.md

Generates a comprehensive guide for AI agents to understand and contribute to the codebase.

```
/cr-agents              # Generate AGENTS.md
/cr-agents update       # Update existing AGENTS.md (preserves manual additions)
```

**AGENTS.md includes**: Project overview, tech stack, directory map, where to add new code,
architecture patterns, key flows (Mermaid diagrams), naming conventions, import rules,
environment variables, testing strategy, deployment flow, decisions log.

---

## `/cr-research` — Feature Research

Investigates how to integrate a new feature. Produces **theoretical analysis + implementation plan**.

```
/cr-research add user authentication with OAuth2
/cr-research migrate from REST to GraphQL
/cr-research add real-time notifications with WebSockets
```

**Theoretical analysis**: Impact assessment, recommended approach, design alternatives (pros/cons),
trade-offs, risks & mitigations, new dependencies.

**Implementation plan**: Prerequisites, step-by-step (files, complexity, dependencies),
interfaces & contracts, tests needed, migration plan, rollback strategy, checklist.

---

## Project Configuration

Create `.review-agent.yml` in your project root to customize all commands:

```yaml
# Stack override (skip auto-detection)
stacks:
  - frontend
  - backend

# Default mode for /cr
default_mode: deep

# Custom rules per command
rules:
  cr:
    - "All API endpoints must have rate limiting"
    - "Repository pattern for all DB access"
  refactor:
    - "Functions over 20 lines should be flagged"
  arch:
    - "Must follow hexagonal architecture"
  research:
    - "All new features must have rollback strategy"

# Paths to ignore
ignore:
  - "vendor/"
  - "node_modules/"
  - "*.generated.go"

# Severity overrides
severity:
  no_any_type: must_fix
  missing_error_handling: must_fix
```

Install the template with `--with-config`:

```bash
bash install-claude-code.sh --with-config
```

---

## Pre-push Hook

Automatically runs a quick code review before every push (non-blocking).

```bash
# Install with the installer
bash install-claude-code.sh --with-hooks

# Or manually
bash hooks/install-hook.sh

# Uninstall
bash hooks/install-hook.sh --uninstall
```

---

## Stack Detection

| Files detected | Subagent |
|---------------|----------|
| `.ts`, `.tsx`, `.jsx`, `.css`, `.scss`, `.html` | `frontend-reviewer` |
| `.go`, `.py`, `.proto`, `.graphql` | `backend-reviewer` |
| `.sql` + dbt indicators | `data-reviewer` |
| Any file | `security-checker` (always, in deep/quick modes) |

---

## Agents

### Review (`/cr`)

| Agent | Role |
|-------|------|
| `review-agent` | Orchestrator — diff, detect, delegate, consolidate |
| `frontend-reviewer` | React, TypeScript, a11y, performance |
| `backend-reviewer` | Go, Python, API design, SQL |
| `data-reviewer` | dbt, SQL transforms, warehouse patterns |
| `security-checker` | OWASP security audit |

### Refactoring (`/cr-refactor`)

| Agent | Role |
|-------|------|
| `refactor-agent` | Orchestrator — gather code, delegate |
| `refactor-analyzer` | Deep code smell analysis |

### Architecture (`/cr-arch`)

| Agent | Role |
|-------|------|
| `arch-agent` | Orchestrator — scan, delegate, generate |
| `frontend-arch-analyzer` | Frontend architecture analysis |
| `backend-arch-analyzer` | Backend architecture analysis |

### AGENTS.md (`/cr-agents`)

| Agent | Role |
|-------|------|
| `agents-doc-generator` | Orchestrator — delegate, generate |
| `codebase-mapper` | Structure, naming, stack, deps, tests |
| `flow-tracer` | Flows, decisions, deployment, patterns |

### Research (`/cr-research`)

| Agent | Role |
|-------|------|
| `research-agent` | Orchestrator — understand, delegate, consolidate |
| `theory-analyzer` | Impact, trade-offs, alternatives, risks |
| `implementation-planner` | Step-by-step plan, tests, rollback |

### Skills (lazy-loaded)

| Skill | Used by | Purpose |
|-------|---------|---------|
| `frontend-reference` | frontend-reviewer | React, TS patterns, anti-patterns |
| `backend-reference` | backend-reviewer | Go, Python, API patterns |
| `data-reference` | data-reviewer | dbt, SQL, warehouse patterns |
| `refactoring-patterns` | refactor-analyzer | Code smells catalog |
| `architecture-patterns` | arch analyzers | Architecture patterns catalog |

---

## File Structure

```
review-agent/
  agents/                              # OpenCode agents
    review-agent.md                      # /cr orchestrator
    frontend-reviewer.md                 # Frontend review subagent
    backend-reviewer.md                  # Backend review subagent
    data-reviewer.md                     # Data review subagent
    security-checker.md                  # Security review subagent
    refactor-agent.md                    # /cr-refactor orchestrator
    refactor-analyzer.md                 # Refactoring subagent
    arch-agent.md                        # /cr-arch orchestrator
    frontend-arch-analyzer.md            # Frontend arch subagent
    backend-arch-analyzer.md             # Backend arch subagent
    agents-doc-generator.md              # /cr-agents orchestrator
    codebase-mapper.md                   # Codebase mapping subagent
    flow-tracer.md                       # Flow tracing subagent
    research-agent.md                    # /cr-research orchestrator
    theory-analyzer.md                   # Theory analysis subagent
    implementation-planner.md            # Implementation planning subagent
  skills/                              # Lazy-loaded reference skills
    frontend-reference/SKILL.md
    backend-reference/SKILL.md
    data-reference/SKILL.md
    refactoring-patterns/SKILL.md
    architecture-patterns/SKILL.md
  claude-code/                         # Claude Code agents & commands
    agents/                              # Same agents, Claude Code format
    commands/
      cr.md                              # /cr command
      cr-refactor.md                     # /cr-refactor command
      cr-arch.md                         # /cr-arch command
      cr-agents.md                       # /cr-agents command
      cr-research.md                     # /cr-research command
  hooks/
    pre-push-review.sh                   # Git pre-push hook
    install-hook.sh                      # Hook installer
  .review-agent.example.yml             # Config template
  install.sh                           # OpenCode installer
  install-claude-code.sh               # Claude Code installer
```
