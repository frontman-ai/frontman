---
"@frontman/client": patch
---

Remove dead "Calling " prefix stripping from tool label helpers. No production server code sends tool names with this prefix; the branches were unreachable legacy code.
