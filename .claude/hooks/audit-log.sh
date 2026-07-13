#!/usr/bin/env bash
# PostToolUse hook (all tools) — append one JSON line per action to
# .claude/audit/audit.jsonl.
#
# Runs AFTER the tool has executed, so it records actions that actually ran
# (blocked actions are logged separately by the PreToolUse guards). This hook is
# observe-only: it always exits 0 and never affects the tool result.
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

tool = p.get("tool_name", "")
ti = p.get("tool_input") or {}
resp = p.get("tool_response")

# Command vs file target depending on the tool.
command = ti.get("command", "") if tool == "Bash" else ""
file = ti.get("file_path", "") if tool in ("Write", "Edit", "MultiEdit", "Read", "NotebookEdit") else ""

# Best-effort success/error read from the tool response (shape varies by tool).
result = "ok"
if isinstance(resp, dict):
    if resp.get("error") or resp.get("is_error"):
        result = "error"
    elif "success" in resp:
        result = "ok" if resp.get("success") else "error"
elif isinstance(resp, str):
    result = "error" if resp.lower().startswith("error") else "ok"

rec = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "session_id": p.get("session_id", ""),
    "tool": tool,
    "command": command,
    "file": file,
    "cwd": p.get("cwd", ""),
    "result": result,
    "hook": "audit-log",
}
with (audit / "audit.jsonl").open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
PY

exit 0
