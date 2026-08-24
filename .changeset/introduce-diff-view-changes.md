---
"@frontman-ai/client": minor
"@frontman-ai/frontman-core": minor
"@frontman-ai/frontman-protocol": minor
---

Add a Changes view that shows file edits made during a conversation as diffs. File-editing tools now emit file change events over a new file change protocol message, and the client renders them with `@pierre/diffs`.
