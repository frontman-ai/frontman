---
"@frontman-ai/client": patch
---

Require live preview context before sending prompts. Keep submission disabled until the preview connects, and retain failed messages for retry or removal. Store the runtime with its task and keep in-flight sends bound to their originating task. Avoid cross-origin errors when collecting legacy iframe references.
