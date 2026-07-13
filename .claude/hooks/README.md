# `.claude/hooks/` — governance guardrails

Wired in [`../settings.json`](../settings.json). All hooks receive the Claude Code
hook payload as JSON on **stdin** and use `$CLAUDE_PROJECT_DIR` (the repo root).

| Hook | Event | Matcher | Effect |
|------|-------|---------|--------|
| `validate-bash.py` | PreToolUse | `Bash` | Denies recursive+force deletes, `DROP TABLE`, force push, `mkfs`, fork bombs, `curl\|sh`, raw-disk writes, `chmod -R 777`. |
| `check-secrets.py` | PreToolUse | `Write\|Edit\|MultiEdit` | Denies writes containing AWS/GitHub/Slack/Google/OpenAI keys, PEM private keys, or hardcoded credentials (`api_key=`, `token=`, `password=`). |
| `scope-guard.sh` | PreToolUse | `Write\|Edit\|MultiEdit` | Denies in-repo writes outside the allow-listed dirs (`src app docs tests scripts .claude`). Out-of-repo writes (scratchpad / `/tmp`) pass. |
| `audit-log.sh` | PostToolUse | `*` | Appends one JSON line per executed action to `audit/audit.jsonl`. |
| `log-prompt.sh` | UserPromptSubmit | — | Appends each user prompt to `audit/prompts.jsonl`. |
| `session-report.sh` | Stop | — | Writes `audit/reports/session-<id>.md` (action / block / error counts). |

## Deny mechanics

A PreToolUse hook that **exits 2** denies the tool call; its **stderr** is fed back
to Claude. Exit 0 = allow. On any internal error the guards fail **open** (exit 0)
so a hook bug can never wedge the session. Blocked attempts are recorded to
`audit/audit.jsonl` with `"result": "blocked"` so the Stop report can count them.

## Activation

Hooks are loaded at session start. After editing `settings.json` or these scripts,
run `/hooks` to review, or restart the Claude Code session, for changes to take effect.

## Testing

`tests/test_hooks.py` is the real suite — `pytest -q` runs every guard against a
blocked and an allowed payload. To poke one by hand, feed it a fake payload on
stdin and read the exit code; nothing destructive actually runs. The secret example
splits the fake token across two shell strings (`"AKIA""..."`) so this very file
does not trip its own scanner; bash rejoins them at runtime.

```bash
# BLOCKED bash (expect exit 2 + reason on stderr)
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' \
  | python3 .claude/hooks/validate-bash.py; echo "exit=$?"

# ALLOWED bash (expect exit 0, no output)
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
  | python3 .claude/hooks/validate-bash.py; echo "exit=$?"

# BLOCKED secret (expect exit 2)
FAKE="AKIA""IOSFODNN7EXAMPLE"
echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"src/x.py\",\"content\":\"K=$FAKE\"}}" \
  | python3 .claude/hooks/check-secrets.py; echo "exit=$?"

# ALLOWED write — env reference, not a literal secret (expect exit 0)
echo '{"tool_name":"Write","tool_input":{"file_path":"src/x.py","content":"K=os.environ[\"AWS_KEY\"]"}}' \
  | python3 .claude/hooks/check-secrets.py; echo "exit=$?"

# BLOCKED scope — outside allow-list but inside repo (expect exit 2)
echo "{\"tool_name\":\"Write\",\"cwd\":\"$PWD\",\"tool_input\":{\"file_path\":\"$PWD/secret.txt\"}}" \
  | CLAUDE_PROJECT_DIR="$PWD" bash .claude/hooks/scope-guard.sh; echo "exit=$?"

# ALLOWED scope — inside src/ (expect exit 0)
echo "{\"tool_name\":\"Write\",\"cwd\":\"$PWD\",\"tool_input\":{\"file_path\":\"$PWD/src/x.py\"}}" \
  | CLAUDE_PROJECT_DIR="$PWD" bash .claude/hooks/scope-guard.sh; echo "exit=$?"
```
