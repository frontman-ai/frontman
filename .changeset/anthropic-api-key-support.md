---
"frontman_server": minor
---

Add Anthropic API key support as alternative to OAuth

- Introduce Provider as first-class domain concept with Registry, Model, and Codex modules
- Centralize LLM wiring in ResolvedKey.to_llm_args with enforced context boundaries
- Drive image dimension constraints from Provider Registry
- Add Anthropic API key configuration UI in client settings
- Extract shared parsing helpers into domain modules
