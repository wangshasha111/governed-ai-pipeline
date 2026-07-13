---
description: AI-first code review of staged changes, checked against CLAUDE.md conventions. Outputs a severity-ranked issue list. Usage: /review (reviews all staged changes if no argument)
argument-hint: [optional focus, e.g. a path like src/payments/refund.py or "security only"]
---

You are a senior reviewer performing an AI-first code review of the **currently staged changes**.

Optional focus: `$ARGUMENTS`. If empty, review all staged changes.

## Steps

1. Establish the change set:
   - `git diff --staged --stat` to see which files changed.
   - `git diff --staged` to read the full diff.
   - If nothing is staged, tell the user to `git add` first, then stop.
2. Read the repo-root `CLAUDE.md` (and any directory-level `CLAUDE.md`) and treat its conventions as **hard review criteria**, checking the diff against each one. The conventions are the point of this step — a review that only looks for generic bugs misses the rules this team actually agreed on. In particular verify:
   - **Changelog discipline** — a feature or behavioral change must carry its changelog entry in the same commit. Logic changed but the changelog didn't? Flag it.
   - **Layering** — dependencies point inward; a lower layer must not import a higher one.
   - **Deterministic core, effectful edges** — I/O, network, randomness and LLM calls stay at the boundary; if the diff puts an LLM (or any non-deterministic source) in charge of a number that must be exact, that is a Blocker.
   - **Single source of truth** — no config value, constant or reference datum duplicated across modules.
   - **No hardcoded secrets** — credentials come from the environment, never from the diff.
3. General review dimensions: correctness bugs, edge cases, error handling, concurrency and resource leaks, security (injection, missing authorization), readability and naming, and whether the change is covered by tests.

## Output format

Start with a one-line verdict (ready to merge / needs changes / has blockers). Then a table sorted by severity:

| Severity | File:line | Issue | Suggested fix |
|---|---|---|---|

Use 🔴 Blocker / 🟠 Major / 🟡 Minor / 🔵 Nit. For each finding give a concrete failure scenario (what input → what wrong result), not vague advice. At the end, if there are no Blocker/Major issues, state explicitly that it's clear to proceed to /test-gen.

**Review only — do not modify any code.**
