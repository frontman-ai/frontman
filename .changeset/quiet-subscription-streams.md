---
"@frontman-ai/frontman-client": patch
"@frontman/frontman-server-assets": patch
---

Handle browser MCP subscriptions with validated filters, correlated acknowledgments, cancellation, and attachment teardown. Accept MCP server notification envelopes in Phoenix without treating them as tool responses. Browser change-event categories remain unsupported; Phoenix does not open subscriptions automatically.

Cancel and complete active subscriptions before intentional session teardown. Drop request state without replay after transport loss. Reject request ID reuse while tool calls remain pending or suspended.
