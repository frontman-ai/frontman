---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Model client connection ownership with explicit initialization, authentication, ready, and closing phases. Retain pending connections and failed sessions for cleanup, and cancel ACP connection waits when their lifetime ends.
