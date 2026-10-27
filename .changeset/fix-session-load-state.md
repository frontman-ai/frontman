---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-protocol": patch
---

Restore server-owned pending messages, execution state, and plans through regular session loading. Keep queued follow-ups cancellable after reload and move only messages explicitly claimed by the server into the transcript.
