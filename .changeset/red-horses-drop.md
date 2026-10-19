---
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-core": patch
"@frontman-ai/nextjs": patch
---

Use a shared typed record for relay tool definitions. Tool names are required strings, and callers no longer decode them from JSON.

Preserve vendor metadata and JSON Schema extensions. Unknown top-level tool fields are no longer forwarded.
