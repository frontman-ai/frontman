---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Fix connection loss and server-initiated channel closure that left the agent UI stuck. Preserve received text and the last server-reported execution state. Settle pending ACP requests and disable disconnected controls with a reload option.
