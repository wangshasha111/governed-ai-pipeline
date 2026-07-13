---
description: Generate an onboarding brief for a new team member — architecture summary, key-files map, and a conventions cheat sheet. Usage: /onboard (pass an area to focus, e.g. "backend")
argument-hint: [optional focus area, e.g. backend, frontend, or a module name]
---

You produce a concise onboarding brief for a developer joining this codebase.

Optional focus: `$ARGUMENTS` (e.g. `backend`, `frontend`, a specific module). If empty, cover the whole system at a high level.

## Gather (read, don't guess)

1. `CLAUDE.md` (root and any directory-level ones) — the source of truth for conventions.
2. `README*`, `docs/`, and the package manifests (`requirements.txt`, `package.json`, `pyproject.toml`).
3. Skim the top-level source layout to confirm the **real** structure before describing it.
4. `git log --oneline -20` for a sense of what's active right now.

## Output — one brief, three sections

**1. Architecture summary.** Short prose: what the app does, the major pieces and how they talk to each other, and the request/data flow end to end. The mental model a newcomer needs — not an exhaustive catalog.

**2. Key files map.** A table of the highest-leverage files and dirs:

| Path | What it is / when you'd touch it |
|---|---|

Include entry points, core domain logic, the state/data model, config, and where tests live.

**3. Conventions cheat sheet.** The rules that are *not* obvious from reading the code, pulled from `CLAUDE.md` and `docs/`:
- **Workflow rules** (branching, changelog discipline, how a change gets shipped).
- **Architecture conventions** (layering, ordering constraints, what must never be violated).
- **Testing standards** (framework, where tests go, what must be stubbed).

Close with **"First-day setup"**: the exact commands to get the app running locally, plus prerequisites.

Keep it skimmable — a new hire should be productive after reading it once. Do not modify any files.
