---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Reload task sessions when switching back to an existing chat so pending questions and preview tools resume without a refresh. Replay history into a fresh message store, discard detached question callbacks, and log detached requests and late tool completions.
