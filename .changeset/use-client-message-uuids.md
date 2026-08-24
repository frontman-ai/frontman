---
"@frontman-ai/client": minor
---

Require `_meta["frontman.dev/messageId"]` on `session/prompt` requests and use it as the canonical persisted user-message UUID for live updates and history replay. Missing, malformed, and duplicate IDs now return invalid params; older clients that omit this metadata are incompatible.
