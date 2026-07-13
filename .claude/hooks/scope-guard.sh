#!/usr/bin/env bash
# PreToolUse hook (matcher: Write|Edit|MultiEdit) — keep in-repo writes inside
# an allow-listed set of directories.
#
# Rationale: file edits should only ever land in the code/docs/tooling dirs we
# expect. A write that resolves to a project-relative path OUTSIDE the allow-list
# is denied (exit 2). Writes that resolve OUTSIDE the repo entirely (e.g. the
# session scratchpad under /tmp) are NOT this guard's concern and pass through.
#
# Edit the ALLOWED array below to widen/narrow scope.
set -euo pipefail

# --- directories that in-repo writes are allowed to touch (repo-relative) ---
ALLOWED=("src" "app" "docs" "tests" "scripts" ".claude")

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
PAYLOAD="$(cat)"

# Pull file_path out of the JSON payload with python3 (always present here).
FILE_PATH="$(printf '%s' "$PAYLOAD" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print((d.get("tool_input") or {}).get("file_path","") or "")
except Exception:
    print("")')"

# Nothing to check.
[ -z "$FILE_PATH" ] && exit 0

audit_block() {
  local reason="$1"
  PROJECT_DIR="$PROJECT_DIR" PAYLOAD="$PAYLOAD" REASON="$reason" python3 <<'PY' 2>/dev/null || true
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
    "tool": p.get("tool_name", ""),
    "command": "",
    "file": (p.get("tool_input") or {}).get("file_path", ""),
    "cwd": p.get("cwd", ""),
    "result": "blocked",
    "hook": "scope-guard",
    "reason": os.environ.get("REASON", ""),
}
with (audit / "audit.jsonl").open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
PY
}

# Resolve the target to an absolute path (it may not exist yet).
case "$FILE_PATH" in
  /*) ABS="$FILE_PATH" ;;
  *)  ABS="$PROJECT_DIR/$FILE_PATH" ;;
esac
# Normalise .. / . without requiring the file to exist.
ABS="$(python3 -c 'import os,sys; print(os.path.normpath(sys.argv[1]))' "$ABS")"

# Writes outside the repo entirely (scratchpad, /tmp, ...) are not our concern.
case "$ABS" in
  "$PROJECT_DIR"/*) ;;   # inside repo -> keep checking
  *) exit 0 ;;
esac

REL="${ABS#"$PROJECT_DIR"/}"
TOP="${REL%%/*}"

for dir in "${ALLOWED[@]}"; do
  if [ "$TOP" = "$dir" ]; then
    exit 0
  fi
done

REASON="write outside allow-listed dirs (${ALLOWED[*]}): $REL"
audit_block "$REASON"
{
  echo "[scope-guard] BLOCKED: $REASON"
  echo "  Allowed top-level dirs: ${ALLOWED[*]}"
  echo "  Put the file under one of those, or add its dir to ALLOWED in .claude/hooks/scope-guard.sh"
} >&2
exit 2
