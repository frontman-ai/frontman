---
"@frontman/frontman-server-assets": patch
---

Reject MCP tool schemas with more than 10,000 JSON nodes before runtime compilation. Previously accepted larger schemas now fail validation. Each schema has its own budget; object keys do not count.
