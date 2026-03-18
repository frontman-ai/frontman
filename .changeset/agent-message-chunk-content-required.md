---
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Make AgentMessageChunk content field required per ACP ContentChunk spec. Removes unnecessary option wrapper and simplifies downstream consumer code.
