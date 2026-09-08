---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Fix connection loss that left the agent UI stuck. Failed channels now settle pending ACP requests, clear local activity, and show a reload option.
