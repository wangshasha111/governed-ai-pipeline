# The Governed AI Pipeline

A portable `.claude/` directory that turns Claude Code from an ad-hoc assistant into
**team infrastructure**: five slash commands that encode the workflow, three PreToolUse
hooks that *deny* dangerous actions, three logging hooks that make every session
auditable, and a permissions config that gates the rest.

Built and tested against a real production codebase — a Python/FastAPI backend running a
multi-step LLM pipeline behind a TypeScript SPA. **The target application's source code is
not in this repository (corporate policy).** What's here is the graded deliverable: the
governance infrastructure itself, which is designed to drop into *any* repo. Every number
in the docs comes from real runs against the real project; identifying details are
generalised.

Week 3 assignment — *Claude Code: AI-Augmented Software Engineering*.

## What's here

| Path | What it is |
|---|---|
| [`.claude/commands/`](.claude/commands) | `/review`, `/test-gen`, `/commit`, `/ship`, `/onboard` — the workflow, encoded |
| [`.claude/hooks/`](.claude/hooks) | 3 guards that block (dangerous bash, leaked secrets, out-of-scope writes) + 3 that log (actions, prompts, session summary). [Details](.claude/hooks/README.md) |
| [`.claude/settings.json`](.claude/settings.json) | Permission allow/deny lists, permission mode, and the hook wiring |
| [`.claude/audit/`](.claude/audit) | Sample audit logs from a real session — including three real blocks |
| [`CLAUDE.md`](CLAUDE.md) | Team workflow rules, architecture conventions, testing standards |
| [`docs/workflow-map.md`](docs/workflow-map.md) | The current developer workflow, annotated with time / tools / pain |
| [`docs/leverage-analysis.md`](docs/leverage-analysis.md) | Automation Leverage Framework scoring → the top 3 targets |
| [`docs/roi-report.md`](docs/roi-report.md) | Before/after measurements, weekly savings, projected annual ROI |
| [`docs/governance-playbook.md`](docs/governance-playbook.md) | 6-week rollout plan for a 10-person team |
| [`REPORT.md`](REPORT.md) | Written answers to all 12 assignment questions |
| [`tests/test_hooks.py`](tests/test_hooks.py) | 41 tests driving every hook the way Claude Code does |

## Try it

```bash
git clone https://github.com/wangshasha111/governed-ai-pipeline
cd governed-ai-pipeline
pip install -r requirements-dev.txt

# Run the guard suite (41 tests). COVERAGE_PROCESS_START lets coverage follow the
# hooks into their subprocesses — see .coveragerc.
COVERAGE_PROCESS_START="$PWD/.coveragerc" pytest tests -q --cov --cov-report=term-missing
```

Expected: **41 passed**, ~89% coverage on the two Python guards.

To use the pipeline itself, open Claude Code in this directory and run `/onboard`, or
stage a change and run `/review`. The hooks load at session start — Claude Code will ask
you to approve them the first time.

## The guards, in one line each

- **`validate-bash.py`** — denies recursive+force deletes, `DROP TABLE`, force push,
  `mkfs`, `dd` to a raw device, fork bombs, `curl | sh`, `chmod -R 777`.
- **`check-secrets.py`** — denies any write containing an AWS/GitHub/Slack/Google/OpenAI
  key, a PEM private key, or a hardcoded credential; allows `os.environ[...]` references
  and placeholders, so it pushes people toward the right pattern instead of just saying no.
- **`scope-guard.sh`** — denies in-repo writes outside the allow-listed directories
  (including `../` traversal escapes).

All three deny by exiting 2, record the attempt to `audit.jsonl`, and **fail open** on an
internal error — a bug in a guard can never wedge the session.
