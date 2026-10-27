---
"@frontman/frontman-server-assets": patch
---

Propagate agent cancellation to dispatched MCP attempts after recording durable cancellation intent. Fence dispatch and late results by turn and request ID, retain actual late evidence without waking a newer turn, and prevent automatic replay of uncertain attempts. Cancellation does not imply rollback.
