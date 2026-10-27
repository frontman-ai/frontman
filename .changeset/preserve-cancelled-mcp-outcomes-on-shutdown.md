---
"@frontman/frontman-server-assets": patch
---

Preserve an MCP attempt's unknown outcome when shutdown follows durable cancellation intent. Do not replace it with a synthetic restart error or replay an interactive attempt with cancellation intent.
