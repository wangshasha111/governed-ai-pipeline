# Changelog

Human-readable companion to `git log` — newest first, one bullet per change.

## 2026-07-13

- **guards** — `validate-bash` now blocks local history/worktree destruction:
  `git reset --hard` (discards uncommitted work) and `git clean -f` (deletes
  untracked files). Both are irreversible and neither leaves a reflog entry to
  recover from. `git reset --soft` and `git clean -n`/`--dry-run` stay allowed.
- **repo** — added this changelog, per the changelog discipline in `CLAUDE.md`.

## 2026-07-12

- **initial** — the governed AI pipeline: slash commands (`/review`, `/test-gen`,
  `/commit`, `/ship`, `/onboard`), the hook guards (`validate-bash`,
  `check-secrets`, `scope-guard`), and the audit trail (`audit-log`,
  `log-prompt`, `session-report`).
