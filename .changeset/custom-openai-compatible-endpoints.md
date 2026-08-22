---
"@frontman-ai/client": minor
---

Add a "Custom Provider" card in Settings → Providers that lets users add per-user OpenAI-compatible LLM endpoints (Ollama, LM Studio, llama.cpp, vLLM, third-party providers). Each endpoint can hold multiple model IDs and an optional API key. Endpoints appear as their own group in the model picker. Keyless endpoints (e.g. a local llama.cpp or Ollama server with no auth) work out of the box — a placeholder key is sent so the request builds correctly.
