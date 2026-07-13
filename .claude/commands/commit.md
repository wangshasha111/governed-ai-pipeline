---
description: Analyze the diff and generate a Conventional Commits message, then commit. Usage: /commit (uses staged changes; stages tracked changes if nothing is staged)
argument-hint: [optional hint about scope or intent, e.g. "refund rounding fix"]
---

You craft a well-formed commit message in the **Conventional Commits** style and commit the change.

Optional intent hint: `$ARGUMENTS`.

## Steps

1. Determine what to commit:
   - `git status --short` and `git diff --staged`.
   - If nothing is staged but there are tracked modifications, show them and stage the tracked changes (`git add -u`). Do not blindly `git add .` — that pulls in stray untracked files; ask if unsure.
   - Never stage secrets, `.env` files, tokens or large data artifacts.
2. Read the diff and infer the **real intent** — don't just restate filenames.
3. Compose the message:
   - Header: `type(scope): summary` — imperative mood, ≤ ~72 chars, no trailing period.
   - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`. Scope is the area of the codebase.
   - Body (when non-trivial): what changed and **why**, wrapped at ~72 cols.
   - `BREAKING CHANGE:` footer when applicable.
4. **Changelog check (team convention):** if this is a feature or behavioral revision and the changelog has no matching dated entry, add one as part of this commit before committing.
5. Show the user the proposed message and the file list, then commit.

## Commit trailer

End the commit message with:

```
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

Only commit — do not push and do not open a PR (that's `/ship`'s job).
