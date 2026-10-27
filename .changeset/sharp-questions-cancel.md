---
"@frontman-ai/client": patch
---

Stop an interactive question when its MCP request is cancelled. Route cleanup through task actions scoped to the exact question execution, without sending another session-cancel command. Return the existing cancelled-question output and keep other tasks and newer questions active.
