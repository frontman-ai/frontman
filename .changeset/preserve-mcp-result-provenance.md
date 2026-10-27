---
"@frontman/frontman-server-assets": patch
---

Keep validated peer-final tool results distinct from locally synthesized MRTR declines and unsupported-content failures. Local failures cannot resolve a cancelled attempt's unknown outcome, even with a matching request ID. Preserve the controlled MRTR decline for active calls.
