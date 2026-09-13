---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-core": patch
"@frontman-ai/frontman-protocol": patch
---

Restore custom-provider settings during the MCP migration. Use one Sury version so malformed MCP responses return errors correctly. Remove obsolete schemas and fail schema checks on every mismatch.
