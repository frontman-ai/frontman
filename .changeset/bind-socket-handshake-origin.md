---
"@frontman/frontman-server-assets": patch
---

Bind embedded client WebSocket authentication to the actual browser handshake origin instead of a client-supplied socket parameter. Reject missing, malformed, duplicate, or unapproved handshake origins while preserving dynamically approved embedding sites and localhost development.
