# The Governed AI Pipeline — Written Report

**GitHub repo:** https://github.com/wangshasha111/governed-ai-pipeline
**Author:** ShaSha Wang · Week 3 — Claude Code: AI-Augmented Software Engineering

> **On the target repository.** The pipeline was built against, and tested on, a real production
> codebase: a Python/FastAPI backend running a multi-step LLM pipeline behind a TypeScript SPA.
> **That application's source code is omitted from this repository under corporate policy.** What
> is here is the graded deliverable — the portable governance infrastructure — plus a second live
> target (this repo itself), which is where `/ship` was run end to end and where the hooks now
> guard their own source. Every measurement below is from a real run; identifying details of the
> employer's system are generalised, nothing is fabricated.

---

## Thinking Questions

### Q1. Why is "map before you automate" important? What would happen if you built slash commands without understanding your workflow first?

Because automation multiplies whatever you point it at — including waste. If you skip the map,
you optimise the step that *feels* slow rather than the one that *is* expensive, and you make a
bad process faster instead of making it shorter.

The map ([`docs/workflow-map.md`](docs/workflow-map.md)) changed what I built. My gut said
"Implementation is the bottleneck" — it *is* the biggest slice (120 of 315 minutes per change).
But scoring it in [`docs/leverage-analysis.md`](docs/leverage-analysis.md) ranked it **6th** for
automation, because it's interactive and creative: it can't be reduced to one deterministic
command, and Claude Code already helps inside the editing loop. Meanwhile **Testing (ROI 9)**,
**Review (ROI 9)** and **Merge (ROI 8)** scored highest — not because they're the slowest, but
because they're *frequent × mechanical × rule-bound*, and that product is what a slash command
can actually own. A step scores high only when all three axes align. Had I skipped the analysis,
I'd have poured effort into an `/implement` command that would have been a worse version of a
conversation.

The second failure mode is subtler: **automating an inefficient process cements it.** Our
changelog rule was a step people forgot half the time. The right response isn't a slash command
that nags — it's `/commit` writing the entry as part of the commit, so the rule stops depending
on memory. You can only see that distinction if you've written the step down first.

### Q2. How did the /ship pipeline change your development experience compared to manual git add, commit, push, PR creation?

**Measured, not remembered:** [PR #1](https://github.com/wangshasha111/governed-ai-pipeline/pull/1),
7 minutes wall-clock end to end (6.3 min of audited tool activity — timestamps in
`.claude/audit/audit.jsonl`, session `<SHIP-SESSION>`), against an estimated ~55 minutes to do
the same task by hand. Four things changed:

**Speed** — ~8×, and the biggest chunk isn't typing, it's *not stalling*. The manual path has
dead air: staring at a diff deciding if it's fine; deciding whether the change deserves tests;
composing a commit message. `/ship` collapses that into one decision — accept or intervene.

**Consistency** — the four gates run in the same order every time whether or not I'm tired. In
the measured run, `/test-gen` wrote 9 tests (41 → 50 passing) and `/commit` created the changelog
entry. On a Friday evening, manual-me writes neither.

**Error reduction** — this is the one that surprised me. Writing tests for a 5-line regex change,
the pipeline **found a real bug in that change**: keying the `git clean` rule on `-d` made it
misfire on the `-d` inside `--dry-run`, so `git clean --dry-run` would have been blocked and
`git clean -f` let through — wrong in both directions. It was fixed before merge. The manual
baseline for a change that small ships that bug.

**Cognitive load** — down, but *reallocated*, not removed. I stopped tracking "did I stage it,
did I write the changelog, is the PR body decent" and started doing the one job I'm actually
needed for: judging whether the change is right. Which mattered, because the run hit two guard
blocks (Q3) and *deciding how to respond to a false positive is not a decision I want automated.*

Honest caveat: `/ship` is not hands-off. I approved permission prompts several times and made one
judgement call mid-run. It's an accelerator with a human in the loop, not an autopilot — and the
gates are worth exactly as much as the human who reads the output.

### Q3. Describe a scenario where your validation hooks saved you from a real (or simulated) mistake. What would have happened without the hook?

I'll give both kinds, because they teach different lessons — and the false positives are the more
interesting story.

**The simulated saves (three, one per guard).** In the guardrail demo (audit log, session
`<SESSION>`):

| Guard | Attempted | Would have happened |
|---|---|---|
| `validate-bash` | recursive+force delete | Files deleted, no undo, no trash |
| `check-secrets` | write a file containing an `AKIA…` AWS key | A live-looking credential committed to git history — where deleting the file doesn't remove it |
| `scope-guard` | write to `data/` (outside the allow-list) | A stray file in a directory nobody reviews |

**The real blocks (two, during the actual `/ship` run) — both false positives, and that's the
point.** The guards fired on *me*, mid-workflow, on PR #1:

1. `git commit -F -` with a heredoc whose message body quoted the words `git push --force` → **blocked**.
2. `gh pr create --title "…git reset --hard…"` → **blocked by the very rule the PR was adding.**

Neither command would have executed anything dangerous. `validate-bash` regexes the whole shell
string and can't tell the command being *run* from text quoted *inside* it — so the guard fires
precisely when you're trying to *explain* a dangerous command. (It caught me twice more while
writing this repo: once on a commit message mentioning `rm -rf`, once on a test file containing a
literal PEM header. The tests now assemble fake credentials from fragments at runtime, with a
comment saying why.)

What I did about it is the part I'd defend in a review: **I did not disable the hook, and I did
not reword the truth to sneak past the regex.** The commit message and PR body went into files,
passed with `-F` / `--body-file` — so the *executed* command was genuinely clean while the guard
stayed on. The limitation is filed as a known issue (strip heredoc bodies and quoted strings
before matching), because a guard that cries wolf on honest work is a guard people will
eventually turn off. That is why [`docs/governance-playbook.md`](docs/governance-playbook.md)
runs a **dry-run week** before enforcement: measure the false-positive rate on ten people's real
work *before* it starts denying.

### Q4. Your audit logs capture everything Claude does. How would you use this data in a SOC2 audit? What's missing?

**What the log already supports.** Each line is `{timestamp, session_id, tool, command, file, cwd,
result, hook, reason}`, which answers three of the auditor's questions directly:

- *What happened, and when* — every executed action, UTC-timestamped (**CC7.2**, monitoring).
- *What was prevented* — every blocked attempt with the guard and the reason (**CC6.1**, logical
  access / restriction of privileged operations). Five blocks on record, all reconstructable.
- *Was the control operating during the period* — the Stop-hook session reports give per-session
  counts, which is the "evidence of continuous operation" an auditor asks for.

Concretely, in a SOC2 walkthrough I would use it to demonstrate a **change-management control**:
show that AI-authored changes reached `main` only through `/ship`, whose gates are review → tests
→ commit → PR, and show `audit.jsonl` as the tamper-evident trail of what the assistant did along
the way.

**What's missing — and it's disqualifying as-is:**

1. **Identity.** `session_id` is a UUID, not a person. An auditor needs *who*. Fix: stamp the git
   author / SSO identity into every record.
2. **Immutability.** The log is a local JSONL file the developer can edit with `vi`. A log the
   subject can rewrite is not evidence. Fix: ship to append-only, retained, access-controlled
   storage the developer cannot write to.
3. **Approval chain.** The log has *what*, not *who approved it*. There's no link from an action to
   the ticket that authorised it or the reviewer who accepted the PR. Fix: carry ticket ID and PR
   approver into the record.
4. **The "why".** `prompts.jsonl` gets closest — it's the intent behind each action — but it's the
   most sensitive file here and needs its own retention and access policy before it can be shipped
   anywhere central.
5. **Bypassability.** `--dangerously-skip-permissions` skips every local hook. A control that the
   controlled party can switch off is a guardrail, not a gate. Anything that *must* hold belongs
   in CI or branch protection, server-side.

Summary: today the logs are strong **engineering telemetry** and weak **compliance evidence**.
The gap is not detail — it's *identity, immutability, and non-bypassability*.

### Q5. If you had to present your ROI report to your engineering director, what's the single most compelling number? How would you defend it?

**"48 minutes saved per shipped change — 55 down to 7."** Not the annual dollar figure. The
dollar figure is a *derivative*; if the director doesn't believe the 48 minutes, no amount of
multiplying makes it true.

How I defend it:

- **The 7 minutes is measured, not remembered.** It's the delta between the first and last
  timestamp of session `<SHIP-SESSION>` in an audit log written by a hook, not by me. The PR is
  public. Anyone can re-run it.
- **I'd volunteer the weak half.** The 55-minute manual baseline is *estimated* — itemised from
  the workflow map, not stopwatched. That's the number to attack, and I'd say so before they do.
  Halve the saving to 24 min/change and the case still clears its cost by two orders of magnitude.
- **The full arithmetic is in the open** ([`docs/roi-report.md`](docs/roi-report.md)): 48 min ×
  4 changes/week × 46 weeks × 10 devs ÷ 60 = 1,472 h/yr ≈ **$220,800** at $150/hr. I use 4
  changes/week (the map implies daily) and 46 weeks (not 52) deliberately, so every assumption
  errs low.
- **Then I'd cut my own number in half in the room.** Saved minutes don't convert 1:1 into
  shipped output. **~$110k** is what I'd put in the business case, and framing it that way is what
  makes the other numbers credible.

If pressed for a *non*-financial number instead, I'd use this one: **the pipeline found a real bug
in a 5-line change before it merged** (Q2). One prevented production incident is worth more than
the entire time saving, and it's the argument that survives a skeptical CFO.

### Q6. What's the difference between "permission modes" and "hooks" as governance mechanisms? When would you use each?

**Permissions are a bouncer with a guest list. Hooks are a security guard who reads what you're
carrying.**

| | Permissions | Hooks |
|---|---|---|
| Granularity | Coarse: tool + pattern (`Bash(git push:*)`) | Fine: arbitrary code over the full tool input |
| Decision | Static list, matched | Programmable — regex, file lookups, git state, an API call |
| Configured | Declaratively in `settings.json` | Executable scripts |
| Failure mode | Prompts the human (annoying but safe) | Exits 2 and **denies**, with a reason fed back to Claude |
| Answers | "*May* you use this tool?" | "Given *what you're about to do*, should this specific call proceed?" |

The distinction that matters in practice: a permission rule can say *"`Bash(git push:*)` needs
approval"*. It cannot say *"allow `git push`, unless it's a force-push, unless it's
`--force-with-lease`."* That's a decision about the **content** of the command, and only code can
make it. Same on the write side: permissions can gate `Write`; only `check-secrets.py` can allow
`api_key = os.environ["KEY"]` while denying `api_key = "AKIA…"` — same tool, same file, opposite
verdicts.

**Use permissions** for the broad, stable posture: allow-list the read-only and routine dev
commands so the assistant isn't stopping every 30 seconds (`ls`, `git status`, `pytest`);
deny-list what should never run in any form. That's the cheap, declarative 80%.

**Use hooks** for content-dependent judgement, for anything that must be *recorded* rather than
merely allowed (all logging is hooks — permissions can't observe), and for rules with exceptions.

**They're layers, not alternatives**, and mine deliberately overlap: `permissions.deny` lists
force-push *and* `validate-bash.py` blocks it. Belt and braces — because hooks fire regardless of
permission mode, and defaultMode `"default"` keeps a human in the loop for the grey zone in
between. The permission list is the door; the hook is what happens if someone comes in through a
window.

### Q7. How would your governance setup need to change for a team of 50 vs. a team of 5?

|  | Team of 5 | Team of 10 (what I built) | Team of 50 |
|---|---|---|---|
| **Settings** | One repo `settings.json`, edited by whoever needs it | Same, but changes go through PR review | Enterprise **managed policy** that individuals cannot weaken, + per-repo overrides for the parts that legitimately differ |
| **Hook ownership** | The person who wrote them | Named owner + backup | A platform/DevEx team owns them as a **versioned, released package** — repos pin a version, not a copy-paste |
| **Audit volume** | A few MB of JSONL; grep is fine | Tens of MB; local is fine, `jq` is fine | GBs/month — a real log pipeline, retention policy, and *someone whose job it is to look* |
| **False positives** | Fixed in a Slack thread same day | Weekly review of blocks | A **triage queue with an SLA** — one bad pattern now burns 50 people's afternoons |
| **Rollout** | Just turn it on | 6-week plan with a dry-run week | Staged by team, with an opt-out escape hatch and a support rota |

**What scales.** The **commands** — a good `/review` is exactly as useful to person 50 as to
person 1, and adoption is voluntary and self-reinforcing. The **deny-list** scales too: it's short,
stable, and universally true (nobody's job requires `mkfs`).

**What doesn't.** Two things break, and both break *silently* — in the direction of nobody
noticing:

1. **Informal ownership.** At 5, "the person who wrote the hooks" is a real answer. At 50, that
   person left, the regex is stale, and a guard that's never updated is a guard that's slowly
   drifting away from what's actually dangerous.
2. **Local logs.** Fine for 5 (you can read them all). At 50 they're just noise on 50 laptops —
   nobody reads them, so the control exists on paper only. Central, immutable, alertable storage
   isn't a nice-to-have at that size; it's the difference between having a control and having a
   file.

The other thing that changes at 50 is **you must stop relying on local hooks for anything
critical**. One person running `--dangerously-skip-permissions` bypasses everything here. At 5,
you know who would; at 50, you don't. Whatever *must* hold moves server-side: CI checks, branch
protection, org policy. The local hooks stay — they're the fast feedback loop that keeps mistakes
cheap — but they stop being the last line of defence.

---

## Tactical Questions

### Q8. Show the full content of your /ship command. Walk through each step and explain why it's in that order.

`.claude/commands/ship.md`:

````markdown
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
````

**Why this order — each stage earns the right to run the next.**

**Stage 0 (preconditions) first** because everything downstream assumes a git repo with something
to ship, on a branch that isn't `main`. Discovering *at the PR step* that you've been committing
to `main` is the expensive way to learn it. Cheapest check, so it goes first.

**Review before tests**, and this is the ordering people most often get backwards. Both orders
"work", but review is the cheaper gate (seconds; no test suite to run) and it can catch things
tests structurally cannot: a hardcoded secret, a layering violation, a missing changelog entry.
And it prevents the worst outcome in the pipeline — **generating tests for code that shouldn't
exist.** If `/review` finds a Blocker, everything after it was wasted work. Fail on the cheap
gate first.

**Tests before commit** because a commit is the first thing that's *awkward to undo*. Everything
before it is free: no history, nothing to amend or revert. Once you commit, unwinding means
`reset` or `revert` — and `git reset --hard` is now blocked by my own guard, which is a nice
demonstration of why you'd rather not need it. So the last hard gate goes immediately before the
first irreversible step. Red tests → nothing is committed → nothing to undo.

**Commit before PR** is forced by git, but the *interesting* ordering choice is that the commit
message is written **after** review and tests, not before. It can therefore state what actually
happened — "9 tests added, suite green at 50" — rather than what was hoped for. Test results from
Stage 2 flow straight into the PR body.

**PR last**, because it's the only stage with an audience. Pushing a branch and opening a PR is
the first thing another human sees, and the first thing that's *socially* expensive to retract.
Everything before it exists to make sure that what they see is worth their time.

The through-line: **each stage is ordered by cost of failure, cheapest first, with the
irreversible steps at the end.** Fail fast, fail loud, fail *before* the expensive part.

### Q9. Show your validate-bash.py hook code. What patterns does it block? How does it read the tool input?

**How it reads the tool input.** Claude Code sends the hook a JSON payload on **stdin** before the
tool runs:

```json
{"session_id": "...", "cwd": "...", "tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}
```

The hook reads stdin, `json.loads` it, pulls `tool_input.command`, and signals its verdict
**through the exit code**: `exit 2` = **DENY** (stderr is fed back to Claude as the reason);
`exit 0` = allow. Any internal failure also exits 0 — the guard **fails open**, so a bug in a hook
can never wedge a session.

`.claude/hooks/validate-bash.py` (full):

```python
#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) — block dangerous shell commands.

Reads the Claude Code hook payload from stdin:
    {"session_id": "...", "cwd": "...", "tool_name": "Bash",
     "tool_input": {"command": "..."}}

If the command matches a dangerous pattern, we:
  * append a "blocked" record to .claude/audit/audit.jsonl,
  * print the reason to stderr,
  * exit 2 -> Claude Code DENIES the tool call and feeds stderr back to Claude.

Exit 0 lets the command through. Any other failure also exits 0 (fail-open on
our own bugs, so a hook error never wedges the session).
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


def project_dir() -> Path:
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env)
    # .claude/hooks/validate-bash.py -> parents[2] == project root
    return Path(__file__).resolve().parents[2]


def audit_block(payload: dict, reason: str) -> None:
    """Record a blocked attempt so the Stop-hook report can count it."""
    try:
        audit_dir = project_dir() / ".claude" / "audit"
        audit_dir.mkdir(parents=True, exist_ok=True)
        record = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "session_id": payload.get("session_id", ""),
            "tool": payload.get("tool_name", "Bash"),
            "command": (payload.get("tool_input") or {}).get("command", ""),
            "file": "",
            "cwd": payload.get("cwd", ""),
            "result": "blocked",
            "hook": "validate-bash",
            "reason": reason,
        }
        with (audit_dir / "audit.jsonl").open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except Exception:
        pass  # auditing must never break the guard


# Each entry: (compiled regex, human-readable reason).
DANGEROUS = [
    # rm with BOTH a recursive-ish and a force-ish flag, in any order/spelling.
    (re.compile(r"\brm\b(?=.*(?:-\w*r|--recursive))(?=.*(?:-\w*f|--force))", re.I),
     "recursive+force delete (rm -rf / rm -fr / rm -r -f)"),
    # rm of an obviously catastrophic target.
    (re.compile(r"\brm\b[^|;&]*\s(/|~|/\*|\$HOME)\s*($|[;&|])"),
     "rm targeting / ~ or $HOME"),
    # Destructive SQL.
    (re.compile(r"\bdrop\s+(table|database|schema)\b", re.I),
     "destructive SQL (DROP TABLE/DATABASE/SCHEMA)"),
    (re.compile(r"\btruncate\s+table\b", re.I),
     "destructive SQL (TRUNCATE TABLE)"),
    # Force push.
    (re.compile(r"git\s+push\b(?!.*--force-with-lease)(?=.*(?:--force\b|\s-f\b|\s\+\w))", re.I),
     "git push --force (use --force-with-lease if you truly need it)"),
    # Local history/worktree destruction — uncommitted work is unrecoverable.
    (re.compile(r"git\s+reset\b[^|;&]*--hard", re.I),
     "git reset --hard (discards uncommitted work irreversibly)"),
    (re.compile(r"git\s+clean\b(?=[^|;&]*-\w*f)", re.I),
     "git clean -f (deletes untracked files irreversibly)"),
    # Filesystem creation / disk overwrite.
    (re.compile(r"\bmkfs(\.\w+)?\b", re.I), "mkfs (formats a filesystem)"),
    (re.compile(r"\bdd\b[^|;&]*\bof=/dev/", re.I), "dd writing to a raw device"),
    (re.compile(r">\s*/dev/(sd|nvme|disk|hd|mmcblk)", re.I), "redirect onto a raw disk device"),
    # Fork bomb: :(){ :|:& };:
    (re.compile(r":\s*\(\s*\)\s*\{.*:\s*\|\s*:", re.S), "fork bomb"),
    (re.compile(r"\}\s*;\s*:\s*$"), "fork bomb"),
    # Pipe-from-network straight into a shell/interpreter.
    (re.compile(r"\b(curl|wget|fetch)\b[^|]*\|\s*(sudo\s+)?(sh|bash|zsh|dash|python\d?|perl|ruby)\b", re.I),
     "curl|sh — piping a remote script straight into a shell"),
    # World-writable recursive chmod.
    (re.compile(r"\bchmod\s+-R\s+0?777\b", re.I), "chmod -R 777 (world-writable)"),
]


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return 0  # can't parse -> don't block

    command = (payload.get("tool_input") or {}).get("command", "") or ""
    if not command:
        return 0

    for pattern, reason in DANGEROUS:
        if pattern.search(command):
            audit_block(payload, reason)
            sys.stderr.write(
                f"[validate-bash] BLOCKED: {reason}\n"
                f"  command: {command}\n"
                f"  This command was denied by the project's safety hook. "
                f"If you truly need it, ask the human to run it manually.\n"
            )
            return 2  # deny the tool call

    return 0


if __name__ == "__main__":
    sys.exit(main())
```

**What it blocks** (13 patterns, each with a human-readable reason):

| Category | Blocked |
|---|---|
| Destructive delete | recursive + force `rm` in any flag order/spelling; `rm` targeting `/`, `~`, `$HOME` |
| Destructive SQL | `DROP TABLE` / `DROP DATABASE` / `DROP SCHEMA`, `TRUNCATE TABLE` |
| Remote history | `git push --force` / `-f` / refspec `+` — **but `--force-with-lease` is allowed** |
| Local history | `git reset --hard`, `git clean -f` — **but `--soft` and `--dry-run` are allowed** |
| Disk | `mkfs*`, `dd of=/dev/…`, redirect onto a raw device |
| Resource | fork bomb |
| Supply chain | `curl \| sh` (network script piped into any shell/interpreter) |
| Permissions | `chmod -R 777` |

Two design choices worth calling out. **Intent over spelling:** the `rm` rule uses lookaheads for
"recursive-ish" *and* "force-ish" flags, so `rm -rf`, `rm -fr`, `rm -r -f` and `rm --recursive
--force` all match one rule. **Every rule leaves a legitimate door open:** `--force-with-lease`,
`git reset --soft`, `git clean -n` all pass. A guard with no safe alternative just teaches people
to disable it.

**Sample — blocked and allowed:**

```bash
$ echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' \
    | python3 .claude/hooks/validate-bash.py; echo "exit=$?"
[validate-bash] BLOCKED: recursive+force delete (rm -rf / rm -fr / rm -r -f)
  command: rm -rf /
  This command was denied by the project's safety hook. If you truly need it, ask the human to run it manually.
exit=2

$ echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
    | python3 .claude/hooks/validate-bash.py; echo "exit=$?"
exit=0
```

Both directions are covered in the test suite (`tests/test_hooks.py`): 16 dangerous commands must
be denied, 10 safe ones must pass — including the deliberate near-misses `git push
--force-with-lease`, `git reset --soft`, `git clean --dry-run`, and a plain non-recursive `rm`.
**50 tests, 89% coverage** on the Python guards.

**Known limitation** (found by using it, filed on PR #1): it matches the whole shell string, so a
command whose *quoted text* mentions a dangerous command is blocked even though nothing dangerous
would run. It blocked my own commit message and my own PR title (Q3). The fix is to strip heredoc
bodies and quoted strings before matching.

### Q10. Show a sample entry from your audit.jsonl. What fields are captured? How would you query for "all file edits today"?

An **executed action**:

```json
{"timestamp": "2026-07-13T17:15:33.680712+00:00", "session_id": "<SHIP-SESSION>", "tool": "Edit", "command": "", "file": "<REPO>/.claude/hooks/validate-bash.py", "cwd": "<REPO>", "result": "ok", "hook": "audit-log"}
```

A **blocked attempt** (same schema, plus `reason` — this is one of the two real blocks from the
`/ship` run):

```json
{"timestamp": "2026-07-13T17:17:26.805314+00:00", "session_id": "<SHIP-SESSION>", "tool": "Bash", "command": "gh pr create --base main --head demo/ship-e2e --title \"feat(guards): block git reset --hard and git clean -f in validate-bash\" --body \"$(cat <<'BODY' …", "file": "", "cwd": "<REPO>", "result": "blocked", "hook": "validate-bash", "reason": "git reset --hard (discards uncommitted work irreversibly)"}
```

*(The `command` field is reproduced verbatim from the log, truncated at the `--body` heredoc for
length. Note what the record proves: the guard fired on the words `git reset --hard` **in the PR
title** — the command itself would have created a pull request, nothing more.)*

**Fields:**

| Field | What it's for |
|---|---|
| `timestamp` | UTC ISO-8601 — *when* |
| `session_id` | Which conversation — the join key for the Stop-hook report |
| `tool` | `Bash` / `Write` / `Edit` / `Read` / … — *what kind of* action |
| `command` | The shell command (Bash only) |
| `file` | The target path (file tools only) |
| `cwd` | Where it ran |
| `result` | `ok` / `error` / **`blocked`** |
| `hook` | Which hook wrote the line — `audit-log` for executed, the guard's name for blocked |
| `reason` | Why it was denied (blocked records only) |

**"All file edits today":**

```bash
jq -c 'select(.tool == "Edit" or .tool == "Write" or .tool == "MultiEdit")
       | select(.timestamp | startswith("'"$(date -u +%Y-%m-%d)"'"))' \
   .claude/audit/audit.jsonl
```

`$(date -u +%Y-%m-%d)` produces today's UTC date and `startswith` matches the ISO-8601 prefix —
no date parsing needed, which is the whole reason the timestamps are stored in that format.

Two variants an auditor actually asks for next:

```bash
# Everything the guards blocked today, and why
jq -c 'select(.result == "blocked")
       | select(.timestamp | startswith("'"$(date -u +%Y-%m-%d)"'"))
       | {timestamp, hook, reason, command, file}' .claude/audit/audit.jsonl

# Which files were touched most, all time
jq -r 'select(.file != "") | .file' .claude/audit/audit.jsonl | sort | uniq -c | sort -rn
```

### Q11. Show your before/after time measurements for the baseline task. What was the actual speedup?

**The task:** teach `validate-bash` to block `git reset --hard` and `git clean -f`. Shipped as
[PR #1](https://github.com/wangshasha111/governed-ai-pipeline/pull/1) — merged.

📏 = **measured** (from `audit.jsonl` timestamps, session `<SHIP-SESSION>`).
📐 = **estimated** (itemised from [`docs/workflow-map.md`](docs/workflow-map.md); I did **not**
re-do this task by hand with a stopwatch, and I'm not going to pretend otherwise).

| Step | Manual 📐 | `/ship` 📏 | Saved | What actually happened in the measured run |
|---|---:|---:|---:|---|
| Review the staged diff | 10 min | **1.6 min** | 8.4 | diff read against `CLAUDE.md`; no Blocker/Major; gate cleared |
| Write + run tests | 30 min | **1.3 min** | 28.7 | **9 new tests**; suite 41 → **50 passing** |
| Changelog + commit message | 8 min | **0.8 min** | 7.2 | Conventional Commits; `docs/CHANGELOG.md` created |
| Push + open PR | 7 min | **2.3 min** | 4.7 | `git push`, `gh pr create` with test results in the body |
| **Total** | **55 min** | **7 min** | **48 min** | 6.3 min audited tool time; 7 min wall-clock incl. my approvals |

## **Actual speedup: ≈ 7.9× (55 → 7 min).**

**Errors / interventions — the honest part.** The run was **not** clean:

- **2 guard blocks**, both **false positives** (Q3): my own commit message and my own PR title
  mentioned dangerous commands in text, and `validate-bash` matched the whole shell string. Cost
  ~45 s, *inside* the 7 minutes. I routed around them by passing the text via `-F` / `--body-file`
  rather than disabling the guard.
- **1 environment stumble:** the first `pytest` invocation missed the conda env and had to be
  re-run with it.
- **Several permission approvals** from me. `/ship` is not hands-off.

**What the speedup number does *not* capture, and what I'd argue matters more:** `/test-gen` found
a **real bug in the change being shipped** — keying the `git clean` rule on `-d` made it misfire
on the `-d` in `--dry-run`, so `git clean --dry-run` would have been blocked and `git clean -f`
allowed through. Wrong in both directions, fixed before merge. The 55-minute manual baseline,
where a 5-line regex change probably gets no tests at all, ships that bug to `main`.

**Caveats I'd state before anyone else does:**
1. n = 1. One task, one developer, one repo.
2. The baseline is estimated, the pipeline is measured — an asymmetry that flatters the ratio.
3. The task suited the pipeline: small, testable, self-contained. A gnarly cross-module refactor
   would not compress 8×.
4. The 7 minutes excludes my thinking time *before* `/ship` — the change was already staged.

Even discounted hard, the conclusion holds: **on small, frequent, rule-bound changes — which is
most changes — the pipeline is several times faster and produces strictly more (tests, changelog,
PR body) than the manual path.**

### Q12. Show your .claude/settings.json permissions config. Explain each allow and deny rule.

JSON has no comments, so the rationale lives in `//`-prefixed keys (Claude Code ignores unknown
keys) and in [`.claude/hooks/README.md`](.claude/hooks/README.md).

```json
{
  "//": "AI-SDLC governance config. NOTE: JSON has no real comments, so rationale lives in these '//' keys (unknown keys are ignored by Claude Code) and in .claude/hooks/README.md.",
  "//permissionMode": "permissions.defaultMode = 'default' is deliberate. This is a GOVERNANCE setup: the deny-list + PreToolUse hooks are the hard guardrails, and 'default' keeps a human in the loop for everything not explicitly allow-listed (the gray zone). We do NOT use 'acceptEdits' (would auto-run file writes) or 'bypassPermissions' (would skip the very checks this config exists to enforce). Note: hooks fire regardless of mode, so validate-bash / check-secrets / scope-guard still block even if a command were allow-listed.",
  "permissions": {
    "defaultMode": "default",
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(rm -fr:*)",
      "Bash(rm -r -f:*)",
      "Bash(sudo rm:*)",
      "Bash(git push --force:*)",
      "Bash(git push -f:*)",
      "Bash(mkfs:*)",
      "Bash(dd:*)",
      "Bash(chmod -R 777:*)"
    ],
    "allow": [
      "Bash(ls:*)", "Bash(cat:*)", "Bash(head:*)", "Bash(tail:*)",
      "Bash(grep:*)", "Bash(rg:*)", "Bash(find:*)", "Bash(wc:*)", "Bash(pwd)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git show:*)", "Bash(git branch:*)",
      "Bash(git add:*)", "Bash(git commit:*)",
      "Bash(ruff check:*)", "Bash(pytest:*)", "Bash(python3 -m unittest:*)",
      "Bash(npm run:*)", "Bash(npx ng build:*)",
      "Read(//tmp/**)", "Read(//private/tmp/**)"
    ]
  },
  "hooks": { "…": "PreToolUse / PostToolUse / UserPromptSubmit / Stop — see below" }
}
```

*(The `hooks` block is elided here for length; it's in the repo, and Q9 covers the mechanism.
Four events are wired: PreToolUse → `validate-bash` on `Bash` plus `check-secrets` and
`scope-guard` on `Write|Edit|MultiEdit`; PostToolUse → `audit-log`; UserPromptSubmit →
`log-prompt`; Stop → `session-report`.)*

**`defaultMode: "default"`** — the single most important line. Not `acceptEdits` (which would let
file writes run unattended) and emphatically not `bypassPermissions` (which would skip the very
checks this file exists to enforce). "Default" means: allow-listed commands run silently,
deny-listed ones never run, **and everything in the grey zone in between stops and asks a human.**
For a governance setup, the grey zone is exactly where you want a person.

**The deny list — "never, in any form."**

| Rule | Why |
|---|---|
| `rm -rf:*`, `rm -fr:*`, `rm -r -f:*` | Recursive+force delete. Three spellings because the permission matcher is a literal prefix match, not a regex — it can't see that these are the same thing. (`validate-bash.py` *can*, which is precisely why both layers exist.) |
| `sudo rm:*` | Any `rm` with root behind it. Blast radius is the whole machine. |
| `git push --force:*`, `git push -f:*` | Rewrites shared history; other people's work vanishes. `--force-with-lease` is *not* denied — it's the safe version, and a guard with no legitimate alternative gets disabled. |
| `mkfs:*` | Formats a filesystem. No development task needs this. |
| `dd:*` | Raw device writes — one typo away from an unbootable disk. Denied wholesale; the legitimate uses are rare enough to run by hand. |
| `chmod -R 777:*` | Makes a tree world-writable — a security hole that outlives the session that created it. |

**The allow list — "run without asking, because stopping to ask is worse."** The purpose isn't
permissiveness; it's **preserving the value of a prompt**. If Claude stops to ask about `ls`, the
human starts clicking "yes" reflexively — and then clicks "yes" on the one that mattered. Allow
the boring things so the prompts stay meaningful.

| Group | Rules | Why safe |
|---|---|---|
| Read-only shell | `ls`, `cat`, `head`, `tail`, `grep`, `rg`, `find`, `wc`, `pwd` | Cannot mutate anything |
| Read-only git | `git status`, `git diff`, `git log`, `git show`, `git branch` | Inspection only |
| Local-write git | `git add`, `git commit` | Local and reversible — and note what is **absent**: `git push` is *not* allow-listed, so anything that leaves the machine stops for a human |
| Test / lint / build | `pytest`, `ruff check`, `python3 -m unittest`, `npm run`, `npx ng build` | The inner dev loop. These must be frictionless or `/test-gen` and `/ship` become unusable |
| Scratch reads | `Read(//tmp/**)`, `Read(//private/tmp/**)` | The session scratchpad; reading it is harmless |

**The deliberate line: `git add` and `git commit` are allowed; `git push` is not.** Everything
local and undoable is frictionless; the first action with an audience stops and asks.

**Settings hierarchy** (highest wins): enterprise managed policy → CLI args → local project
settings (`.claude/settings.local.json`, git-ignored, personal) → **shared project settings
(`.claude/settings.json` — this file, committed)** → user settings (`~/.claude/settings.json`).

I put the governance config in **`.claude/settings.json`, committed**, deliberately: it's shared,
it's reviewable, and a change to it shows up as a diff in a PR that a human has to approve. A
guard that lives in someone's personal `settings.local.json` isn't a team control — it's a
preference. And at 50 people this same config moves up one level to **enterprise managed policy**,
where individuals can't weaken it at all (Q7).

**Where permissions end and hooks begin.** The deny list can say *"never `git push --force`"*. It
cannot say *"allow `git push`, unless it's a force-push, unless it's `--force-with-lease`"* —
that's a judgement about the command's *content*, and only code can make it. Hence the overlap:
force-push is denied **twice**, by the permission rule and by `validate-bash.py`. Belt and braces.
The permission list is the door; the hook is what happens if someone comes in through a window.
