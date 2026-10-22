---
"@frontman/bindings": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-protocol": patch
---

Add MCP subscription acknowledgments and validate notification filters. Decline state-only interim tool results through the existing error-result path instead of crashing the server channel.

Centralize Phoenix, Vitest, and Sentry bindings. Strengthen MCP regression tests and fix ACP and Sentry test fixtures.
