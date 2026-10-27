---
"@frontman/frontman-server-assets": patch
---

Close task turns under the task lock before cancelling their runtime. Reject queued MCP dispatch and late tool publication from stopped turns, without treating cancellation as proof that external effects stopped.
