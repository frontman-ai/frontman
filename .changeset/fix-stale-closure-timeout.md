---
"@frontman/client": patch
---

Remove dead initialization timeout code (`StartInitializationTimeout`, `InitializationTimeoutExpired`, `ReceivedDiscoveredProjectRule`) that was never wired up — `sessionInitialized` is set via `SetAcpSession` on connection
