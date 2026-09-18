---
"@frontman-ai/client": patch
---

Require live preview context before sending prompts. Keep submission disabled until the preview connects, and retain failed messages for retry or removal. Store the runtime with its task and capture the task, preview, model, and send callback before prompt effects execute. Avoid cross-origin errors when collecting legacy iframe references.
