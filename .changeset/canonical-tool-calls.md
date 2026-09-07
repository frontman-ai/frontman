---
"frontman": patch
---

Persist every declared tool call before execution, including backend calls and calls with invalid arguments. Replay and recovery now use canonical call records instead of reconstructing them from response metadata.

This release requires a maintenance cutover. Stop old server writers before the history backfill runs. See `apps/frontman_server/README.md` for the rollout requirements.
