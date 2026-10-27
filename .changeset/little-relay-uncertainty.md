---
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-protocol": patch
---

Forward browser MCP request cancellation to relay fetches. If execution throws after cancellation, retain an unknown outcome instead of emitting a failed tool result. A real result can still complete a non-cooperative call; cancellation does not imply rollback.
