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
