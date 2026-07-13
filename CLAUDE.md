# CLAUDE.md

This file guides AI coding assistants (and human contributors) working in this
repository. It captures the team's workflow rules, architecture conventions, and
testing standards so that any change — human- or AI-authored — lands consistently.

> This is a generic, submission-safe template. It intentionally contains no
> company-internal system names, deployment targets, credentials, or private API
> details. Fill the bracketed placeholders with your project's specifics.

---

## Team workflow rules

**Branch → change → review → merge.**
- Never commit directly to `main` (or the default branch). Start every change on a
  short-lived feature branch named `type/short-description` (e.g. `feat/user-export`,
  `fix/null-total`).
- Keep changes small and focused — one logical concern per branch and per PR. A
  reviewer should be able to hold the whole diff in their head.

**Commit hygiene.**
- Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`
  in the imperative mood (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`,
  `build`, `ci`). The header explains *what*; the body explains *why*.
- Don't bundle unrelated changes into one commit. Never commit secrets, `.env` files,
  tokens, or large generated artifacts.

**Changelog discipline.**
- Every feature or behavioral change is logged in `docs/CHANGELOG.md` (or `docs/updates.md`),
  newest first, one bullet per change, optionally tagged by area. Add the entry as part of
  the same change — before committing — not as an afterthought. It's the human-readable
  companion to `git log`; write it for a reader.

**Pull requests.**
- Every change reaches `main` through a PR. The PR description states what changed, why,
  and how it was tested. Link related issues.
- A PR is mergeable only when: review has no unresolved blocking comments, and CI (tests +
  lint) is green.

**AI-assisted workflow.**
- Treat AI-generated code like any other contribution: it goes through the same review and
  test gates. Reviewers verify intent and correctness, not just that it runs.
- Prefer small, verifiable steps. When a task is large, split it so each conversation/PR
  stays reviewable.

## Architecture conventions

*(Adapt these to your stack; the principles are the point.)*

- **Clear layering.** Keep boundaries explicit: presentation / API → application/service
  logic → domain logic → data access. Dependencies point inward; lower layers don't import
  higher ones.
- **Deterministic core, effectful edges.** Isolate pure business/computation logic from I/O,
  network, randomness, and (if applicable) LLM calls. This keeps the core easy to test and
  prevents non-deterministic behavior from leaking into results. *If your app uses an LLM,
  never let it perform arithmetic or produce numbers that must be exact — compute those in
  code.*
- **Single source of truth.** Each piece of config, reference data, or shared constant lives
  in exactly one place. Don't duplicate values across modules.
- **Registration order matters.** Where a framework resolves routes/handlers in order (e.g. a
  catch-all/fallback route), register specific handlers before the catch-all.
- **Data-file safety.** Document any file format with hidden pitfalls (e.g. cached
  spreadsheet formulas that a library silently drops on save) and the safe way to edit it.
- **Configuration over hardcoding.** Environment-specific values come from environment
  variables or config, never hardcoded. Provide sane defaults for local development.

## Testing standards

- **What to test.** Cover the deterministic core thoroughly: business logic, calculations,
  edge cases (empty / zero / negative / missing input), and error paths. Every bug fix adds a
  regression test that fails before the fix and passes after.
- **Where tests live.** Mirror the source layout (e.g. `tests/` for backend, `*.spec.*`
  colocated for frontend). Match the existing framework and style — don't introduce a second
  test setup.
- **Stub the edges.** Tests must not call live external services, networks, or LLMs. Stub or
  mock those boundaries so tests are fast, deterministic, and offline.
- **Green means green.** Never weaken or delete an assertion just to make a suite pass. If a
  test fails because of a real defect, fix the code (or flag it) — don't hide it. Report test
  results honestly, including failures.
- **Coverage as a signal, not a target.** Aim for meaningful coverage of critical paths;
  don't chase a percentage with trivial tests. Note uncovered risky paths in the PR.
- **CI gate.** Tests and lint run on every PR and must pass before merge.

---

*Keep this document current. When a convention changes, update it in the same PR that
changes the behavior.*
