---
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/client": patch
---

Keep the draft model preference separate from the session model. Restore the session model on task switches and reconnects. Use `session/set_config_option` for picker changes and preserve accepted-message models for retries. Keep older clients compatible with prompt model metadata.

Require a valid model selection before accepting prompts. Preserve the session selection on creation retries and legacy prompt overrides. Load conversation history even when its model is missing or unavailable. Refresh model options without reporting an agent error. Send catalog options without a server-selected default.
