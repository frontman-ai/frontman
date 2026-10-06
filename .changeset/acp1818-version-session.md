---
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/client": patch
---

Return supported ACP version 1 for valid initialization requests. Reject missing or malformed versions and dispose connections after unsupported response versions.

Use standard session creation fields with optional namespaced retry IDs. Require the advertised retry-ID capability in Frontman clients. Reject unsupported workspace and MCP configuration. Preserve scoped retry identity and reject returned-ID mismatches.

CAUTION: Do not use the unchanged automatic server-first rollout for this breaking session-creation cutover. Deployment requires a separately approved, enforceable client-reload/admission strategy and paired server/client rollback. Old clients send incompatible root session IDs. New clients cannot create sessions on the old server. Publication together does not replace old code in open tabs or custom client URLs. This stage does not change immediate prompt acceptance or its existing 120-second timeout.
