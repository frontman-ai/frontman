---
"@frontman-ai/frontman-protocol": minor
"@frontman-ai/client": minor
"@frontman-ai/frontman-client": minor
---

Model ContentBlock as a discriminated union per ACP spec instead of a flat record with optional fields. Adds TextContent, ImageContent, AudioContent, ResourceLink, and EmbeddedResource variants with compile-time type safety. Wire format unchanged.
