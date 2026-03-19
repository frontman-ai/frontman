---
"@frontman/frontman-protocol": minor
"@frontman/frontman-core": patch
"@frontman/client": patch
---

Replace raw string `type_` field in `toolResultContent` with a typed `toolResultContentType` variant (`Text | Image | Resource`) per MCP spec. Provides compile-time validation that content type values are valid — typos like `"txt"` are now caught at build time.
