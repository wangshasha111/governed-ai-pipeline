#!/usr/bin/env python3
"""PreToolUse hook (matcher: Write|Edit|MultiEdit) — block secret leaks.

Scans the text that is about to be written to disk for hardcoded credentials
(AWS keys, generic api_key=/token=/password=, PEM private-key headers, common
provider tokens). On a hit we append a "blocked" audit record, print the masked
finding to stderr, and exit 2 so Claude Code DENIES the write.

The scanner reads whichever field carries the new content:
    Write     -> tool_input.content
    Edit      -> tool_input.new_string
    MultiEdit -> tool_input.edits[*].new_string
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
    return Path(__file__).resolve().parents[2]


def audit_block(payload: dict, reason: str) -> None:
    try:
        audit_dir = project_dir() / ".claude" / "audit"
        audit_dir.mkdir(parents=True, exist_ok=True)
        record = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "session_id": payload.get("session_id", ""),
            "tool": payload.get("tool_name", ""),
            "command": "",
            "file": (payload.get("tool_input") or {}).get("file_path", ""),
            "cwd": payload.get("cwd", ""),
            "result": "blocked",
            "hook": "check-secrets",
            "reason": reason,
        }
        with (audit_dir / "audit.jsonl").open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except Exception:
        pass


# (compiled regex, label). Ordered specific -> generic.
SECRET_PATTERNS = [
    (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS access key id (AKIA...)"),
    (re.compile(r"ASIA[0-9A-Z]{16}"), "AWS temporary access key id (ASIA...)"),
    (re.compile(r"(?i)aws_secret_access_key\s*[=:]\s*[\"']?[A-Za-z0-9/+]{40}"),
     "AWS secret access key"),
    (re.compile(r"ghp_[A-Za-z0-9]{36}"), "GitHub personal access token (ghp_...)"),
    (re.compile(r"gho_[A-Za-z0-9]{36}"), "GitHub OAuth token (gho_...)"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{50,}"), "GitHub fine-grained PAT"),
    (re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"), "Slack token (xox...)"),
    (re.compile(r"AIza[0-9A-Za-z_\-]{35}"), "Google API key (AIza...)"),
    (re.compile(r"\bsk-[A-Za-z0-9]{20,}"), "OpenAI-style secret key (sk-...)"),
    (re.compile(r"(?i)-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----"),
     "Private key (PEM header)"),
    # Generic "key/token/secret/password = <value>". Value captured for
    # placeholder filtering so we don't fire on os.environ / <your-key> / etc.
    (re.compile(
        r"(?i)\b(?:api[_-]?key|apikey|access[_-]?token|auth[_-]?token|secret|token|passwd|password)"
        r"\s*[=:]\s*[\"']?(?P<val>[^\s\"'#]{12,})[\"']?"),
     "Hardcoded credential (key/token/password = ...)"),
]

# Values that look like references/placeholders rather than real secrets.
PLACEHOLDER = re.compile(
    r"(?i)(os\.environ|getenv|process\.env|env\[|\$\{|<[^>]+>|your[_-]|example|"
    r"changeme|placeholder|xxxx|\*\*\*|redacted|dummy|null|none|true|false)")


def collect_text(tool_input: dict) -> str:
    parts = []
    if isinstance(tool_input.get("content"), str):
        parts.append(tool_input["content"])
    if isinstance(tool_input.get("new_string"), str):
        parts.append(tool_input["new_string"])
    for edit in tool_input.get("edits") or []:
        if isinstance(edit, dict) and isinstance(edit.get("new_string"), str):
            parts.append(edit["new_string"])
    return "\n".join(parts)


def mask(s: str) -> str:
    s = s.strip()
    if len(s) <= 8:
        return s[0] + "***"
    return s[:4] + "***" + s[-2:]


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return 0

    tool_input = payload.get("tool_input") or {}
    text = collect_text(tool_input)
    if not text:
        return 0

    for pattern, label in SECRET_PATTERNS:
        m = pattern.search(text)
        if not m:
            continue
        val = m.groupdict().get("val")
        if val is not None and PLACEHOLDER.search(val):
            continue  # env reference / placeholder, not a real secret
        snippet = mask(val if val else m.group(0))
        audit_block(payload, label)
        sys.stderr.write(
            f"[check-secrets] BLOCKED: possible secret in write -> {label}\n"
            f"  file: {tool_input.get('file_path', '?')}\n"
            f"  match (masked): {snippet}\n"
            f"  Move the secret to an env var / .env (git-ignored) and reference it, "
            f"then retry the write.\n"
        )
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
