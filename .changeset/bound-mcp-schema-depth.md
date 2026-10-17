---
"@frontman/frontman-server-assets": patch
---

Reject MCP tool schemas with map or array containers more than 64 edges below the root before runtime compilation. Previously accepted deeper schemas now fail validation; scalar leaves at depth 65 remain allowed.
