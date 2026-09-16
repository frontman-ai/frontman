---
"@frontman-ai/client": patch
---

Read prompt page context through the preview bridge instead of parent DOM access. Send without live context when the bridge fails. Reject prompts after the originating session changes. Avoid WebKit cross-origin errors when collecting legacy iframe references.
