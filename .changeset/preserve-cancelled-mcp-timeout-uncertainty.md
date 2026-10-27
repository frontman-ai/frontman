---
"@frontman/frontman-server-assets": patch
---

Do not persist an internal timeout as the outcome of an MCP attempt with cancellation intent. Require matching attempt evidence for terminal reconciliation; retain uncertainty when only an executor timeout is known.
