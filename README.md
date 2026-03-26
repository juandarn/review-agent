# review-agent

A code review plugin for [OpenCode](https://opencode.ai) and [Claude Code](https://claude.ai/claude-code) that reviews your code — commits, staged changes, directories, and GitHub pull requests. It auto-detects whether the code is frontend (React/TypeScript), backend (Go/Python), or data engineering (dbt/SQL/warehouse), and delegates to specialized subagents for deep, thorough review.

It knows React hooks rules, TypeScript patterns, Go error handling, Python conventions, dbt model patterns, SQL window functions, JSON handling in warehouses, data quality, StarRocks/Snowflake/BigQuery specifics, API design, and OWASP security best practices.

---

## What It Does

```
You: "review PR #42"
      |
      v
+-----------------------------+
|      review-agent           |
|                             |
|  1. Fetches diff            |
|     (git diff or gh pr diff)|
|  2. Detects stacks from     |
|     file extensions         |
|  3. Delegates to subagents  |
|     IN PARALLEL             |
+-----------+-----------------+
            |
            v (parallel)
  +-------------------+  +------------------+  +------------------+  +------------------+
  | frontend-reviewer |  | backend-reviewer |  |  data-reviewer   |  | security-checker |
  | (if .tsx/.ts/.jsx)|  | (if .go/.py)     |  | (if dbt/.sql+yml)|  | (ALWAYS)         |
  |                   |  |                  |  |                  |  |                  |
  | Loads frontend-ref|  | Loads backend-ref|  | Loads data-ref   |  | OWASP Top 10     |
  | skill if needed   |  | skill if needed  |  | skill if needed  |  | Secrets exposure |
  |                   |  |                  |  |                  |  | Injection vectors|
  | - React patterns  |  | - Error handling |  | - dbt patterns   |  | Auth gaps        |
  | - TypeScript      |  | - Concurrency    |  | - Window funcs   |  | Input validation |
  | - Performance     |  | - API design     |  | - JSON handling  |  | Data protection  |
  | - Accessibility   |  |                  |  | - Data quality   |  |                  |
  +--------+----------+  +--------+---------+  +--------+---------+  +--------+---------+
           |                       |                      |
           +-----------+-----------+----------------------+
                       v
+-----------------------------+
|      review-agent           |
|                             |
|  4. Consolidates all reviews|
|  5. Deduplicates issues     |
|  6. Presents unified report |
|  7. For PRs: asks before    |
|     posting to GitHub       |
+-----------------------------+
```

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

Or manually:

<details>
<summary>OpenCode manual install</summary>

```bash
git clone https://github.com/juandarn/review-agent.git /tmp/review-agent \
  && mkdir -p ~/.config/opencode/agents ~/.config/opencode/skills/frontend-reference ~/.config/opencode/skills/backend-reference ~/.config/opencode/skills/data-reference \
  && cp /tmp/review-agent/agents/*.md ~/.config/opencode/agents/ \
  && cp /tmp/review-agent/skills/frontend-reference/SKILL.md ~/.config/opencode/skills/frontend-reference/ \
  && cp /tmp/review-agent/skills/backend-reference/SKILL.md ~/.config/opencode/skills/backend-reference/ \
  && cp /tmp/review-agent/skills/data-reference/SKILL.md ~/.config/opencode/skills/data-reference/ \
  && rm -rf /tmp/review-agent \
  && echo "Done! Restart OpenCode and press Tab."
```
</details>

<details>
<summary>Claude Code manual install</summary>

```bash
git clone https://github.com/juandarn/review-agent.git /tmp/review-agent \
  && mkdir -p ~/.claude/agents ~/.claude/commands \
  && cp /tmp/review-agent/claude-code/agents/*.md ~/.claude/agents/ \
  && cp /tmp/review-agent/claude-code/commands/*.md ~/.claude/commands/ \
  && rm -rf /tmp/review-agent \
  && echo "Done! Restart Claude Code."
```
</details>

### Install options

```bash
# Install only for the current project
curl -fsSL .../install.sh | bash -s -- --local          # OpenCode
curl -fsSL .../install-claude-code.sh | bash -s -- --local  # Claude Code

# Update existing install (backs up current files)
curl -fsSL .../install.sh | bash -s -- --update

# Uninstall
curl -fsSL .../install.sh | bash -s -- --uninstall
curl -fsSL .../install-claude-code.sh | bash -s -- --uninstall
```

---

## Prerequisites

- [OpenCode](https://opencode.ai) or [Claude Code](https://claude.ai/claude-code) installed
- `gh` CLI installed and authenticated (for PR reviews)

---

## Usage

### OpenCode

1. **Restart OpenCode** after installing
2. Press **Tab** and select `review-agent`
3. Tell it what to review:

### Claude Code

1. **Restart Claude Code** after installing
2. Use `/review` or select `review-agent` from the agent picker
3. Tell it what to review:

### Review local changes

```
review staged changes
```

```
review last commit
```

```
review HEAD~3..HEAD
```

```
review src/api/handlers/
```

### Review pull requests

```
review PR #42
```

```
review https://github.com/org/repo/pull/123
```

The agent will:
- Fetch the diff (via `git diff` or `gh pr diff`)
- Auto-detect frontend and/or backend code by file extensions
- Invoke the relevant subagents in parallel
- Always run the security checker
- Consolidate all findings into a unified report
- For PRs: ask before posting the review to GitHub

---

## How Stack Detection Works

The agent inspects file extensions in the diff:

| Files detected | Subagent invoked |
|---------------|-----------------|
| `.ts`, `.tsx`, `.jsx`, `.css`, `.scss`, `.html` | `frontend-reviewer` |
| `.go`, `.py`, `.proto`, `.graphql` | `backend-reviewer` |
| `.sql` + dbt indicators (`sources.yml`, `{{ ref(`, `models/` paths) | `data-reviewer` |
| Any file | `security-checker` (always) |

If `.sql` files are detected, the agent checks for dbt indicators (Jinja templates, `sources.yml`, `models/` paths). If found, `data-reviewer` is invoked instead of `backend-reviewer` for those files. If the diff contains multiple stacks, all applicable subagents run in parallel.

---

## Agents

| Agent | Type | Role |
|-------|------|------|
| `review-agent` | primary | Orchestrator — gets diff, detects stack, delegates, consolidates |
| `frontend-reviewer` | subagent | React, TypeScript, accessibility, performance, component design |
| `backend-reviewer` | subagent | Go, Python, API design, error handling, concurrency |
| `data-reviewer` | subagent | dbt, SQL transforms, warehouse patterns, JSON handling, data quality |
| `security-checker` | subagent | OWASP security audit — secrets, injection, auth, data protection |

All subagents are **read-only** (no write, no edit, no bash) — they can only review, not modify code.

## Skills (lazy-loaded)

| Skill | Loaded by | Purpose |
|-------|-----------|---------|
| `frontend-reference` | frontend-reviewer | React hooks, TypeScript patterns, performance, accessibility, anti-patterns |
| `backend-reference` | backend-reviewer | Go idioms, Python conventions, API design, anti-patterns |
| `data-reference` | data-reviewer | dbt patterns, SQL window functions, JSON handling, StarRocks/Snowflake/BigQuery, data quality |

Skills are **lazy-loaded** — they only consume tokens when a subagent actually needs to verify a pattern.

---

## Review Output Format

Every review produces a consolidated report:

```
### Summary
Overall assessment of code quality

### Must Fix (blocks merge)
| # | Category | Issue | File:Line | Why | Fix |

### Should Fix (important but not blocking)
| # | Category | Issue | File:Line | Suggestion |

### Nitpicks (nice to have)
| # | Category | Issue | File:Line | Suggestion |

### What's Good
Positive patterns highlighted

### Verdict
APPROVE | APPROVE_WITH_NOTES | REQUEST_CHANGES

### Stats
Files reviewed, issues by category
```

---

## What It Checks

### Frontend (React + TypeScript)
- Hooks rules (dependency arrays, cleanup, derived state)
- Component design (SRP, composition, prop interfaces)
- TypeScript (no `any`, discriminated unions, strict types)
- Performance (memoization, re-renders, code splitting)
- Accessibility (semantic HTML, ARIA, keyboard, focus)
- Styling (design tokens, conditional classes, responsive)

### Backend (Go + Python + API)
- **Go**: error wrapping, concurrency safety, interface design, naming, testing
- **Python**: type hints, exception handling, async patterns, FastAPI/Django
- **API**: REST conventions, status codes, error format, pagination, idempotency

### Data Engineering (dbt + SQL + Warehouse)
- **dbt**: materialization selection, ref/source usage, incremental strategies, CDC dedup
- **SQL**: window functions (nested aggregates), NULL handling, JOIN pitfalls, GROUP BY
- **JSON**: StarRocks/Snowflake/BigQuery JSON functions, array explosion, array size counting
- **Data quality**: schema tests, phantom values, VARCHAR truncation, timezone handling
- **Warehouse**: StarRocks distribution/buckets, MV refresh, Snowflake clustering, BigQuery partitioning

### Security (all stacks)
- Hardcoded secrets and credentials
- SQL/XSS/command injection vectors
- Authentication and authorization gaps
- Input validation and data protection
- Dependency vulnerabilities
- Error message information leakage
- OWASP Top 10 coverage

---

## Customization

### Model

The plugin uses whatever model you've configured in OpenCode — no hardcoded model.
Change your model in OpenCode's settings and all agents will use it automatically.

If you want to override a specific agent, add a `model:` field to its frontmatter:

```yaml
model: anthropic/claude-sonnet-4-6
```

### Per-project install

```bash
bash install.sh --local
```

Or manually:

```bash
mkdir -p .opencode/agents .opencode/skills/frontend-reference .opencode/skills/backend-reference .opencode/skills/data-reference
cp agents/*.md .opencode/agents/
cp skills/frontend-reference/SKILL.md .opencode/skills/frontend-reference/
cp skills/backend-reference/SKILL.md .opencode/skills/backend-reference/
cp skills/data-reference/SKILL.md .opencode/skills/data-reference/
```

---

## File Structure

```
review-agent/
  agents/                          # OpenCode agents
    review-agent.md                  # Primary — orchestrates reviews
    frontend-reviewer.md             # Subagent — React/TS/a11y/perf
    backend-reviewer.md              # Subagent — Go/Python/API
    data-reviewer.md                 # Subagent — dbt/SQL/warehouse/data quality
    security-checker.md              # Subagent — OWASP security audit
  skills/                          # OpenCode skills (lazy-loaded references)
    frontend-reference/
      SKILL.md
    backend-reference/
      SKILL.md
    data-reference/
      SKILL.md
  claude-code/                     # Claude Code agents & commands
    agents/
      review-agent.md               # Primary — orchestrates reviews
      frontend-reviewer.md          # Subagent — React/TS/a11y/perf
      backend-reviewer.md           # Subagent — Go/Python/API
      data-reviewer.md              # Subagent — dbt/SQL/warehouse/data quality
      security-checker.md           # Subagent — OWASP security audit
    commands/
      review.md                     # /review slash command
  install.sh                       # OpenCode installer
  install-claude-code.sh           # Claude Code installer
  README.md                        # This file
```
