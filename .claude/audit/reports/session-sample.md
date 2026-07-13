# Session report — `<SESSION>`

_Generated: 2026-07-13T13:57:45.473262+00:00_

## Totals

- Prompts submitted: **3**
- Tool actions executed: **9**
- Actions blocked by guards: **3**
- Executed actions that errored: **0**

## Executed actions by tool

- `Read`: 8
- `Write`: 1

## Blocked attempts by guard

- `validate-bash`: 1
- `check-secrets`: 1
- `scope-guard`: 1

### Block reasons

- recursive+force delete (rm -rf / rm -fr / rm -r -f) (1)
- AWS access key id (AKIA...) (1)
- write outside allow-listed dirs (src app docs tests scripts .claude): data/hook-scope-test.txt (1)
