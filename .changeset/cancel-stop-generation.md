---
"@frontman/client": minor
"@frontman/frontman-client": minor
---

Add cancel/stop generation support. Users can now stop an in-progress AI agent response by clicking a stop button in the prompt input. Implements the ACP `session/cancel` notification protocol for clean cancellation across client, protocol, and server layers.
