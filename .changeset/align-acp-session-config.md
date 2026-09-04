---
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/frontman-client": patch
---

Restore ACP session startup by making the server own and persist the selected model, returning `currentValue`, and supporting `session/set_config_option`. Keep older clients compatible when they still send model metadata with prompts.
