---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Fix connection loss and server-initiated channel closure that left the agent UI stuck. Preserve received text and the last server-reported execution state. Settle pending ACP requests and disable disconnected controls. Require a reload to recover conversation history instead of automatically rejoining a stale session. Send composer commands directly to the editor instead of routing them through state and effects.
