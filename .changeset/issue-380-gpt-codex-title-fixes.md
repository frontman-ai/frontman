---
---

Fix GPT/Codex model compatibility across chat and title generation. ChatGPT OAuth now routes Codex-family requests through the Responses API with the required endpoint/header options, including support for `gpt-5.3-codex` even when LLMDB is missing that catalog entry. Also improve provider error handling by mapping ReqLLM `:error` stream chunks to clear runtime failures, refresh model lists when provider/key state changes, and keep task ordering/title persistence behavior consistent.
