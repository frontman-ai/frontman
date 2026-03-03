---
"@frontman/frontman-server-assets": patch
---

Fix gpt-5.3-codex custom LLMDB capabilities for OpenRouter and OpenAI providers. Tools, streaming tool_calls, and reasoning were incorrectly disabled, causing silent failures when the agent framework attempted tool calling with this model.
