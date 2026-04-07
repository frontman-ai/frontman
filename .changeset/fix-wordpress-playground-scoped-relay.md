---
"@frontman-ai/client": patch
---

Fix WordPress Playground relay requests to preserve the leading `/scope:...` prefix so tool calls and source-location POSTs do not get redirected to GET.
