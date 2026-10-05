---
"@frontman-ai/client": patch
---

Fix development server startup failing with `:eaddrinuse` by removing an unintended HTTP listener that conflicts with HTTPS. Keep Bandit's default 8 MB fragmented WebSocket message limit.
