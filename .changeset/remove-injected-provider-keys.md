---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-core": patch
"@frontman-ai/frontman-protocol": major
"@frontman-ai/frontman-wordpress": patch
---

Remove unsupported provider-key injection from framework runtime HTML, client settings, ACP metadata, and MCP tool-result metadata. Tool results now use canonical allowlisted persistence, while account-saved BYOK and provider OAuth remain unchanged.

Make MCP tool-result `_meta` optional and generic, align WordPress results with that contract, and stop exposing the unused absolute source root to browser runtime configuration.
