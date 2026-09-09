---
"@frontman-ai/client": minor
"@frontman-ai/astro-browser": minor
"@frontman-ai/frontman-protocol": minor
---

Include the current preview URL in `get_dom` results and fresh client-routing status for Astro only. Keep Astro-specific metadata in the `astro-browser` package, with shared DOM input and output types in the protocol package.

Report unavailable previews and failed queries as MCP errors (`isError: true`), retaining narrowing guidance for size-limit errors. Remove payload-level `success` and `error` fields; successful results always contain the URL, DOM content, node count, and byte size.
