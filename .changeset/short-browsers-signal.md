---
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/client": patch
"@frontman-ai/astro-browser": patch
---

Pass request-scoped cancellation signals through browser MCP execution and local tool interfaces. Cancellation and transport teardown signal running tools without treating abort as proof of rollback. Non-cooperative tools may still return their actual result.
