---
"@frontman/frontman-server-assets": patch
---

Keep validated peer-final tool results distinct from locally synthesized MRTR declines and unsupported-content failures. Local failures cannot resolve a cancelled attempt's unknown outcome, even with a matching request ID. Preserve the controlled MRTR decline for active calls.

Encode opaque attempt keys at the MCP adapter boundary while retaining distinct integer and string request identities. The Tasks context receives transport-neutral keys.
