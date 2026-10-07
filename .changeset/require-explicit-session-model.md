---
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/client": patch
---

Require a valid model selection on the backend. Reject missing or unavailable session models instead of selecting a replacement. Send an unselected model catalog to clients and keep automatic draft selection on the client.
