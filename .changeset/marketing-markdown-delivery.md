---
"marketing": patch
---

Add pricing, access, framework, and documentation Markdown with route-specific discovery and safe GET/HEAD content negotiation. Keep HTML and Markdown pricing in sync.

Negotiated responses use `no-store` because Cloudflare does not guarantee an `Accept`-aware cache key. Static lookups use same-origin URLs without credentials or query parameters.
