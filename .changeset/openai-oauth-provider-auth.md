---
"@frontman-ai/astro": major
"@frontman-ai/client": major
"@frontman-ai/frontman-client": major
"@frontman-ai/frontman-core": major
"@frontman-ai/frontman-protocol": major
"@frontman-ai/nextjs": major
"@frontman-ai/react-statestore": major
"@frontman-ai/vite": major
---

Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.
