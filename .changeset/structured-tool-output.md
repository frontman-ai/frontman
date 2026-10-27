---
"@frontman-ai/frontman-protocol": patch
"@frontman/frontman-server-assets": patch
---

Deliver structured-only MCP tool results to the model, including arrays, scalars, and explicit JSON null. Preserve original text and image blocks and avoid appending structured JSON when an existing text block already contains equivalent serialized JSON. Extend opaque result constructors to accept arbitrary JSON while keeping dictionary-based helpers compatible.
