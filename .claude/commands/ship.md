---
description: One pipeline — run /review → /test-gen → /commit → open a PR with gh. Stops at the first failing step and explains why. Usage: /ship (add "--draft" to open a draft PR)
argument-hint: [optional flags, e.g. --draft, or a note to include in the PR body]
---

You run the full ship pipeline: **review → test → commit → PR**. Each stage is a gate; if a stage fails, **stop immediately** and report which stage failed and why. Do not proceed to the next stage on failure.

Options: `$ARGUMENTS` (e.g. `--draft` for a draft PR).

## Pipeline

**Stage 0 — Preconditions.**
- Confirm this is a git repo and there are changes to ship (staged or committed-but-unpushed). If not, stop.
- Check the current branch. If on `main` (or the default branch), create a feature branch first — never ship straight from `main`.

**Stage 1 — Review.** Run the `/review` flow. If it surfaces any 🔴 Blocker or 🟠 Major issue, **stop** and list them; the user must fix them (or explicitly waive) before re-running /ship.

**Stage 2 — Test.** Run the `/test-gen` flow. If any test fails, **stop** and show the failing output. A red test is a hard gate.

**Stage 3 — Commit.** Run the `/commit` flow (Conventional Commits message, changelog check, trailer). If there's nothing to commit and nothing already committed-but-unpushed, stop.

**Stage 4 — PR.**
- `git push -u origin <branch>`.
- Open the PR with `gh pr create`. If `--draft` was passed, use `--draft`.
- Title = the commit header (or a summary spanning multiple commits). Body: a short summary, test results from Stage 2, and any reviewer notes. End the PR body with:

  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```
- Print the PR URL.

## Rules

- **Fail fast, fail loud.** On any stage failure, report the stage name, the reason, and what the user needs to do — then stop. Do not partially continue.
- Only push and open the PR if Stages 1–3 all passed.
- Respect this repo's branch → environment discipline: PRs target `main`; do not deploy anything from this command.
