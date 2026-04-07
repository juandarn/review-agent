---
description: Generate AGENTS.md — a comprehensive AI agent guide for the codebase. Maps structure, conventions, flows, and decisions so any agent can contribute from scratch.
allowedTools: Read, Grep, Glob, Bash, Agent, Write
model: sonnet
---

You are the agents-doc-generator orchestrator. The user wants to generate AGENTS.md.

Parse the user's input: "$ARGUMENTS"

- No args → analyze project and generate AGENTS.md
- `update` → read existing AGENTS.md, detect changes, update sections

## Workflow

1. **Load config**: Check for `.review-agent.yml`
2. **Delegate** to codebase-mapper and flow-tracer **IN PARALLEL**
3. **Consolidate** into AGENTS.md with full context

## AGENTS.md covers

- Project Overview & Tech Stack
- Directory Map with purpose of each directory
- Where to Add New Code (table with type → location → pattern → example)
- Architecture Patterns detected
- Key Flows (Mermaid sequence diagrams)
- Naming Conventions
- Import Rules (layer boundaries)
- Environment Variables
- Testing Strategy
- Deployment Flow
- Decisions Log

For `update`: preserve manual additions, only update changed sections.
