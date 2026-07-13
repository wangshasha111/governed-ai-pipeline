#!/usr/bin/env bash
# Stop hook — write a per-session summary report when Claude finishes responding.
#
# Aggregates .claude/audit/audit.jsonl and prompts.jsonl for the current
# session_id and writes a markdown report to
# .claude/audit/reports/session-<id>.md (overwritten each Stop so it always
# reflects the latest state). Prints a one-line summary to stdout.
#
# Observe-only: always exits 0 so it never blocks the Stop.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
PAYLOAD="$(cat)"

PROJECT_DIR="$PROJECT_DIR" PAYLOAD="$PAYLOAD" python3 <<'PY' 2>/dev/null || true
import json, os
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

proj = Path(os.environ["PROJECT_DIR"])
audit = proj / ".claude" / "audit"
reports = audit / "reports"
reports.mkdir(parents=True, exist_ok=True)

try:
    p = json.loads(os.environ.get("PAYLOAD") or "{}")
except Exception:
    p = {}
sid = p.get("session_id", "") or "unknown"


def read_jsonl(path):
    rows = []
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception:
                pass
    return rows


actions = [r for r in read_jsonl(audit / "audit.jsonl") if r.get("session_id") == sid]
prompts = [r for r in read_jsonl(audit / "prompts.jsonl") if r.get("session_id") == sid]

executed = [r for r in actions if r.get("result") != "blocked"]
blocked = [r for r in actions if r.get("result") == "blocked"]
errors = [r for r in executed if r.get("result") == "error"]

by_tool = Counter(r.get("tool", "?") for r in executed)
by_hook = Counter(r.get("hook", "?") for r in blocked)
block_reasons = Counter(r.get("reason", "?") for r in blocked)

now = datetime.now(timezone.utc).isoformat()
lines = [
    f"# Session report — `{sid}`",
    "",
    f"_Generated: {now}_",
    "",
    "## Totals",
    "",
    f"- Prompts submitted: **{len(prompts)}**",
    f"- Tool actions executed: **{len(executed)}**",
    f"- Actions blocked by guards: **{len(blocked)}**",
    f"- Executed actions that errored: **{len(errors)}**",
    "",
    "## Executed actions by tool",
    "",
]
lines += [f"- `{tool}`: {n}" for tool, n in by_tool.most_common()] or ["- (none)"]
lines += ["", "## Blocked attempts by guard", ""]
lines += [f"- `{hook}`: {n}" for hook, n in by_hook.most_common()] or ["- (none)"]
if block_reasons:
    lines += ["", "### Block reasons", ""]
    lines += [f"- {reason} ({n})" for reason, n in block_reasons.most_common()]
lines += [""]

(reports / f"session-{sid}.md").write_text("\n".join(lines), encoding="utf-8")

# One-line summary to the transcript.
print(f"[session-report] {sid}: {len(prompts)} prompts, {len(executed)} actions, "
      f"{len(blocked)} blocked, {len(errors)} errors "
      f"-> .claude/audit/reports/session-{sid}.md")
PY

exit 0
