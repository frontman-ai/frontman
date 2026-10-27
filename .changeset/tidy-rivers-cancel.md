---
"@frontman-ai/frontman-client": patch
---

Allow relay tool requests to accept a request-scoped abort signal without aborting sibling calls or the relay connection. Connection teardown still aborts every request. Aborting a request does not establish whether an external write took effect.
