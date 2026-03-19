---
"@frontman/frontman-protocol": minor
"@frontman/frontman-client": minor
"@frontman/client": minor
---

Add ACP-compliant LoadSessionResponse type and unify model selection with SessionConfigOption. Replaces the bespoke /api/models REST endpoint with channel-based config option delivery via session/new, session/load responses and config_option_update notifications. Adds full type tree: SessionModeState, SessionMode, SessionConfigOption (grouped/ungrouped select with category enum), sessionLoadResult. Server pushes config updates after API key saves and OAuth connect/disconnect via PubSub.
