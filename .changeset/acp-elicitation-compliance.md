---
"@frontman-ai/frontman-protocol": minor
"@frontman-ai/frontman-client": patch
"@frontman-ai/client": patch
---

Add ACP elicitation protocol support and enforce compliance across server, protocol, and client layers. Wire up elicitation schema conversion, typed status constants, AgentTurnComplete notification, and idempotent TurnCompleted state transitions. Fix flaky tests and nil description handling in elicitation schemas.
