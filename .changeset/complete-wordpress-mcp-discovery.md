---
"@frontman-ai/frontman-wordpress": patch
---

Return an error instead of a partial MCP tool list when a connected WordPress site's catalog is unavailable or invalid. Load owned connections before parallel HTTP requests so discovery cancellation cannot interrupt a database checkout.
