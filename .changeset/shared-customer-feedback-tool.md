---
"@frontman-ai/client": patch
"@frontman/frontman-server-assets": patch
---

Enable optional customer feedback in WordPress, Astro, Next.js, and Vite through the existing question interaction. Store ratings and skips as ordinary MCP tool results instead of duplicating feedback persistence. Drop the unused customer feedback table and its data. Apply the 30-day cooldown using the user's stored feedback tool interactions. Keep feedback guidance in the tool description.
