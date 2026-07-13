#!/usr/bin/env bash
# UserPromptSubmit hook — append every user prompt to
# .claude/audit/prompts.jsonl (timestamp, session_id, cwd, prompt).
#
# Observe-only: prints nothing and exits 0, so it never injects context into the
# conversation and never blocks a prompt.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
PAYLOAD="$(cat)"

PROJECT_DIR="$PROJECT_DIR" PAYLOAD="$PAYLOAD" python3 <<'PY' 2>/dev/null || true
import json, os
from datetime import datetime, timezone
from pathlib import Path

proj = Path(os.environ["PROJECT_DIR"])
audit = proj / ".claude" / "audit"
audit.mkdir(parents=True, exist_ok=True)

try:
    p = json.loads(os.environ.get("PAYLOAD") or "{}")
except Exception:
    p = {}

rec = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "session_id": p.get("session_id", ""),
    "cwd": p.get("cwd", ""),
    "prompt": p.get("prompt", ""),
}
with (audit / "prompts.jsonl").open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
PY

exit 0
