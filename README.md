# review-agent

An [OpenCode](https://opencode.ai) plugin that reviews your code — commits, staged changes, directories, and GitHub pull requests. It auto-detects whether the code is frontend (React/TypeScript) or backend (Go/Python/SQL), and delegates to specialized subagents for deep, thorough review.

It knows React hooks rules, TypeScript patterns, Go error handling, Python conventions, SQL optimization, API design, and OWASP security best practices.

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
  +-------------------+  +------------------+  +------------------+
  | frontend-reviewer |  | backend-reviewer |  | security-checker |
  | (if .tsx/.ts/.jsx)|  | (if .go/.py/.sql)|  | (ALWAYS)         |
  |                   |  |                  |  |                  |
  | Loads frontend-ref|  | Loads backend-ref|  | OWASP Top 10     |
  | skill if needed   |  | skill if needed  |  | Secrets exposure |
  |                   |  |                  |  | Injection vectors|
  | - React patterns  |  | - Error handling |  | Auth gaps        |
  | - TypeScript      |  | - Concurrency    |  | Input validation |
  | - Performance     |  | - SQL queries    |  | Data protection  |
  | - Accessibility   |  | - API design     |  |                  |
  +--------+----------+  +--------+---------+  +--------+---------+
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

```bash
curl -fsSL https://raw.githubusercontent.com/juandarn/review-agent/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/juandarn/review-agent.git /tmp/review-agent \
  && mkdir -p ~/.config/opencode/agents ~/.config/opencode/skills/frontend-reference ~/.config/opencode/skills/backend-reference \
  && cp /tmp/review-agent/agents/*.md ~/.config/opencode/agents/ \
  && cp /tmp/review-agent/skills/frontend-reference/SKILL.md ~/.config/opencode/skills/frontend-reference/ \
  && cp /tmp/review-agent/skills/backend-reference/SKILL.md ~/.config/opencode/skills/backend-reference/ \
  && rm -rf /tmp/review-agent \
  && echo "Done! Restart OpenCode and press Tab."
```

### Install options

```bash
# Install only for the current project
curl -fsSL .../install.sh | bash -s -- --local

# Update existing install (backs up current files)
curl -fsSL .../install.sh | bash -s -- --update

# Uninstall
curl -fsSL .../install.sh | bash -s -- --uninstall
```

---

## Prerequisites

- [OpenCode](https://opencode.ai) installed
- An LLM provider configured in OpenCode (Anthropic, Google, OpenAI, etc.)
- `gh` CLI installed and authenticated (for PR reviews)

---

## Usage

1. **Restart OpenCode** after installing
2. Press **Tab** and select `review-agent`
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
| `.go`, `.py`, `.sql`, `.proto`, `.graphql` | `backend-reviewer` |
| Any file | `security-checker` (always) |

If the diff contains both frontend and backend files, all three subagents run in parallel.

---

## Agents

| Agent | Type | Role |
|-------|------|------|
| `review-agent` | primary | Orchestrator — gets diff, detects stack, delegates, consolidates |
| `frontend-reviewer` | subagent | React, TypeScript, accessibility, performance, component design |
| `backend-reviewer` | subagent | Go, Python, SQL, API design, error handling, concurrency |
| `security-checker` | subagent | OWASP security audit — secrets, injection, auth, data protection |

All subagents are **read-only** (no write, no edit, no bash) — they can only review, not modify code.

## Skills (lazy-loaded)

| Skill | Loaded by | Purpose |
|-------|-----------|---------|
| `frontend-reference` | frontend-reviewer | React hooks, TypeScript patterns, performance, accessibility, anti-patterns |
| `backend-reference` | backend-reviewer | Go idioms, Python conventions, SQL optimization, API design, anti-patterns |

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

### Backend (Go + Python + SQL + API)
- **Go**: error wrapping, concurrency safety, interface design, naming, testing
- **Python**: type hints, exception handling, async patterns, FastAPI/Django
- **SQL**: parameterized queries, N+1 detection, indexes, migrations, transactions
- **API**: REST conventions, status codes, error format, pagination, idempotency

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
mkdir -p .opencode/agents .opencode/skills/frontend-reference .opencode/skills/backend-reference
cp agents/*.md .opencode/agents/
cp skills/frontend-reference/SKILL.md .opencode/skills/frontend-reference/
cp skills/backend-reference/SKILL.md .opencode/skills/backend-reference/
```

---

## File Structure

```
review-agent/
  agents/
    review-agent.md          # Primary — orchestrates reviews
    frontend-reviewer.md     # Subagent — React/TS/a11y/perf
    backend-reviewer.md      # Subagent — Go/Python/SQL/API
    security-checker.md      # Subagent — OWASP security audit
  skills/
    frontend-reference/
      SKILL.md               # Lazy-loaded React/TS reference
    backend-reference/
      SKILL.md               # Lazy-loaded Go/Python/SQL/API reference
  install.sh                 # One-command installer
  README.md                  # This file
```
