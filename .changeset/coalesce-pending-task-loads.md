---
"@frontman-ai/client": patch
---

Reuse pending session activation when the same task is selected again. This prevents redundant channel joins while preserving retries after failure and explicit session resets.
