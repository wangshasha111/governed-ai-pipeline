---
description: Generate tests for recently changed files, run them, and report coverage. Usage: /test-gen (targets files changed vs. main; pass a path to scope it)
argument-hint: [optional path or file to target, e.g. src/payments/refund.py]
---

You generate and run tests for the code that changed most recently, then report coverage.

Target: `$ARGUMENTS`. If empty, derive the target set from the diff.

## Steps

1. Identify what changed:
   - `git diff --name-only main...HEAD` plus `git status --short` for uncommitted work.
   - Keep source files; drop docs, config and generated files. If a path argument was given, scope to it.
2. For each target file, locate its existing tests and **match the framework and style already in the repo** (mirror the source layout — `tests/` for Python, colocated `*.spec.*` for a JS/TS frontend). Do not introduce a second test setup; extend the existing one.
3. Write focused tests covering the changed behavior, edge cases (empty / zero / negative / missing input) and error paths. Prioritize the deterministic core — pure logic is where tests pay off most. Never write a test that calls a live external service, network or LLM; stub those boundaries.
4. Run them:
   - Python: `pytest <paths> -q`, adding `--cov=<package> --cov-report=term-missing` when `pytest-cov` is available.
   - JS/TS: the project's configured runner (`npm test` / `npx jest` / `npx ng test --watch=false`).
5. If a test fails, show the failing output and fix either the test or — if it exposes a real defect — flag it clearly. **Never weaken an assertion to make a suite pass.**

## Output

- The test files created or updated.
- The actual run output (pass/fail counts). Report failures honestly; never claim green without the run.
- Coverage for the target files (line % and notable uncovered lines). If coverage tooling isn't installed, say so and give a qualitative assessment instead.
- One line: ready for /commit, or what still needs attention.
