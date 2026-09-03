---
"@frontman-ai/client": minor
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-protocol": patch
---

Add editing of the last sent user message. The pencil on the message loads its text back into the composer; sending the edit rewinds the conversation to that point — the original message and everything it produced are dropped on both the client and the server — and the agent answers the edited prompt instead. Only available while the agent is idle.
