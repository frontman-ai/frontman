---
"@frontman/client": patch
---

Fix stale closure bug in initialization timeout that caused `sessionInitialized` to always read as `false` even after being set to `true`
