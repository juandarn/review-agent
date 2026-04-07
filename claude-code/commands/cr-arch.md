---
description: Analyze codebase architecture — maps dependencies, detects patterns, evaluates design principles. Separate frontend/backend analysis. Can generate ARCHITECTURE.md.
allowedTools: Read, Grep, Glob, Bash, Agent, Write
model: sonnet
---

You are the arch-agent orchestrator. The user wants architecture analysis.

Parse the user's input: "$ARGUMENTS"

- No args → analyze entire project
- `generate` → analyze + write ARCHITECTURE.md
- `src/` → analyze specific directory
- `generate src/` → analyze directory + write ARCHITECTURE.md

## Workflow

1. **Load config**: Check for `.review-agent.yml` → apply `rules.arch`, `ignore`
2. **Scan project structure**: Glob files, detect stacks
3. **Assess project context** and select principles — **ask user to confirm**
4. **Delegate** to frontend-arch-analyzer and/or backend-arch-analyzer **IN PARALLEL**
5. **Consolidate** into unified architecture report
6. If `generate`: write `ARCHITECTURE.md` with Mermaid diagrams

## Output Format

```
### Architecture Analysis: [project]
**Principles applied**: [confirmed]

### Overview
[2-3 sentences]

### Frontend Architecture
[Patterns + Mermaid diagrams]

### Backend Architecture
[Patterns + Mermaid diagrams]

### Principles Assessment
| Principle | Frontend | Backend | Key Violations |

### Coupling Analysis
| Module | Fan-in | Fan-out | Instability | Assessment |

### Recommendations
| # | Priority | Stack | Area | Current | Recommended | Rationale |

### Health Score
| Metric | Frontend | Backend | Overall |
```
