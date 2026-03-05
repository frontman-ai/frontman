---
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/client": patch
---

Fix ACP spec deviation: make Plan.entries a required field instead of optional. The ACP spec defines entries as required, so the Option wrapper was incorrect.
