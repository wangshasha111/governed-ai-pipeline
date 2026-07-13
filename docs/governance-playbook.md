# Governance Playbook — 6-Week Rollout for a 10-Person Team

*How to get from "one engineer has a `.claude/` directory" to "the whole team ships through a
governed pipeline" — without a big-bang mandate that everyone quietly ignores.*

The sequencing principle: **observe before you enforce.** Every guard ships first in a mode
where it can only watch, so that when it starts denying, we already know what it would have
denied and no one is surprised. Nothing here is irreversible; each week has a named rollback.

---

## Week 0 — Prerequisites (before the clock starts)

| | |
|---|---|
| **Owner** | Pipeline owner (the engineer who built this) |
| **Goal** | The infrastructure exists, is tested, and has a home |

- `.claude/` merged to `main` of the target repo: 5 commands, 6 hooks, `settings.json`, `CLAUDE.md`.
- `pytest tests/test_hooks.py` green in CI — **the guards are code, and code that isn't tested
  isn't a control.**
- A `#claude-code` channel exists for questions and false-positive reports.
- One named **pipeline owner** and one **backup**. A control with no owner decays.

---

## Week 1 — Land the commands. Enforce nothing.

**Goal:** the team feels the upside before it feels any friction.

- Ship `.claude/commands/` only. Hooks stay **out** of `settings.json` this week.
- Kickoff demo (30 min): `/onboard` on the team's own repo, then `/review` on a real staged diff.
- Ask every engineer to run `/review` at least once before their next PR. That's the whole ask.

**Milestone:** ≥ 7/10 engineers have run `/review` or `/test-gen` on real work.
**Risk:** commands feel like ceremony → **Mitigation:** no mandate this week; adoption is voluntary
and the demo uses *their* code, not a toy.
**Rollback:** delete `.claude/commands/` — zero blast radius, nothing else depends on it.

---

## Week 2 — Logging on. Still enforcing nothing.

**Goal:** get a baseline of what Claude actually does across ten people, before any guard fires.

- Enable the three **observe-only** hooks: `audit-log` (PostToolUse), `log-prompt`
  (UserPromptSubmit), `session-report` (Stop).
- Announce it explicitly — *"every prompt and every tool call is now logged locally."* Logging that
  people discover later is a trust incident, not a control.
- End of week: read the logs together. Which tools dominate? What would the guards have blocked?

**Milestone:** ≥ 5 sessions/day logging across the team; a one-page "what we saw" summary.
**Risk:** surveillance framing. **Mitigation:** the logs are engineering telemetry, not performance
management — say so out loud, and say who can read them. Never use a prompt log in a performance
review; if that line is crossed once, adoption dies.
**Rollback:** remove the three hook entries from `settings.json`.

---

## Week 3 — Guards in **dry-run**.

**Goal:** measure the false-positive rate *before* anyone is blocked by it.

- Deploy `validate-bash`, `check-secrets`, `scope-guard` — but patched to log and **exit 0**
  instead of exit 2 (`DRY_RUN=1`). They record `"result": "would_block"`.
- Collect every would-block for a week. Tune the patterns against reality:
  - `check-secrets` must not fire on `os.environ[...]` or `<placeholder>` values.
  - `scope-guard`'s allow-list must match how this team actually lays out the repo.

**Milestone:** a week of would-block data; false-positive rate **< 5%** of flagged actions.
**Risk:** a noisy guard trains people to ignore guards. **Mitigation:** that's precisely what
dry-run week exists to prevent — tune first, enforce second.
**Rollback:** trivial; nothing is being denied yet.

---

## Week 4 — Enforcement on.

**Goal:** the guards start saying no.

- Flip `DRY_RUN` off: PreToolUse hooks now **exit 2** and deny.
- Turn on the `permissions.deny` list in `settings.json` (the coarse gate) alongside them.
- Publish the escape hatch **on day one**: a blocked command a human genuinely needs is run *by a
  human in their own terminal*, not by weakening the guard. A guard that can be argued away in a
  Slack thread isn't a guard.
- Every block is logged. Review the week's blocks on Friday: real save, or false positive?

**Milestone:** enforcement live for all 10; ≥ 1 genuine block; zero people disabling the hooks.
**Risk:** someone deletes `settings.json` locally to move faster. **Mitigation:** the settings file
is in git and CI checks it exists and parses; a PR that removes a guard is a visible PR.
**Rollback:** patterns can be relaxed individually — never disable a guard wholesale to unblock
one person.

---

## Week 5 — `/ship` as the default path to `main`.

**Goal:** the pipeline becomes the road, not a detour.

- Team norm: PRs are opened with `/ship`. Its gates (review clean → tests green → then and only
  then commit + PR) become the definition of "ready".
- Add coverage reporting to `/test-gen` output; track it per PR.
- Now that `/ship` gates on green tests, wire the same tests into CI as the server-side backstop.
  **A local hook is a guardrail, not a gate — CI is the gate.** Someone with `--dangerously-skip
  -permissions` can bypass every local hook; they cannot bypass a required status check.

**Milestone:** ≥ 80% of PRs opened via `/ship`; test coverage on changed files trending up.
**Risk:** `/ship` blocks on a flaky test and people route around it. **Mitigation:** fix or quarantine
the flake the same day — a gate that's routinely bypassed is worse than no gate.
**Rollback:** `/ship` stays available; the *norm* relaxes back to manual PRs.

---

## Week 6 — Measure, harden, hand over.

**Goal:** prove the value and make it someone's job.

- Publish the ROI report with the team's own numbers (not one engineer's): time per PR before vs
  after, blocks triggered, coverage delta.
- Ship the audit logs somewhere durable: today they're local JSONL, which is fine for one person
  and useless for compliance. Forward to the central log store with **retention and immutability**
  (see "What's still missing" below).
- Rotate the pipeline owner. Add a monthly 30-min review of new block patterns and false positives.

**Milestone:** ROI report presented; audit logs centralised; owner rotation scheduled.

---

## What's still missing (be honest about it)

The setup here is a strong *engineering* control and an incomplete *compliance* control:

- **Local, mutable logs.** `audit.jsonl` sits on the developer's laptop and they can edit it. For
  SOC2 it must be shipped to append-only storage the developer can't write to.
- **No approval chain.** The log captures *what* happened, not *who approved it*. Tie each session
  to a ticket and each merge to a PR approver.
- **No identity.** `session_id` is not a person. Add the git author / SSO identity to every record.
- **Local hooks are bypassable.** `--dangerously-skip-permissions` skips them all. Anything that
  truly must not happen belongs in CI or a server-side branch protection rule, not only here.

## Scaling notes: 5 → 10 → 50

| | Team of 5 | Team of 10 (this plan) | Team of 50 |
|---|---|---|---|
| **Settings** | One repo `.claude/settings.json` | Same, reviewed in PRs | Enterprise managed policy + per-repo overrides; individuals can't weaken the base |
| **Hook maintenance** | Whoever wrote them | Named owner + backup | A platform/DevEx team owns them as a versioned package, released like a dependency |
| **Audit volume** | A few MB of JSONL | Tens of MB; local is fine | GBs — needs a real log pipeline, retention policy, and someone paid to watch dashboards |
| **False positives** | Fix in a Slack thread | Weekly review | A triage queue with an SLA; a bad pattern now costs 50 people's time |

What scales: **the commands** (a good `/review` is as useful at 50 as at 5) and **the deny list**.
What doesn't: **informal ownership** and **local-only logs** — both quietly break somewhere around
15–20 people, and they break in the direction of *nobody noticed*.
