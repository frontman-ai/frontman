# MCP Troubleshooting

Use categorical diagnostics. Never log authorization values, nonces, tool
arguments, schema bodies, result payloads, or parser exception text.

| Symptom | Meaning | Safe check |
| --- | --- | --- |
| Empty `403` | Origin failed or authorization was insufficient | Compare canonical Origin; confirm WordPress `manage_options` |
| Empty `401` | Authentication missing | Confirm credential presence without printing it |
| `429` with `Retry-After` | Principal exhausted 256/60-second budget | Wait for expiry; do not rotate credentials to evade policy |
| Empty `503` | Limiter key/state/capacity failed closed | Inspect categorical health and cleanup, never keys/state |
| `405` | Wrong method | Send uppercase `POST`; preflight is uppercase `OPTIONS` |
| `415` | Request media rejected | Use JSON, optionally `charset=utf-8` |
| `406` | Response offer rejected | Offer JSON and SSE |
| `400`, `-32020` | Header/body mismatch | Check field sources and Base64-sentinel use without logging values |
| `400`, `-32022` | Unsupported version | Use `2026-07-28`; no legacy fallback exists |
| `400`, `-32602` | Request metadata malformed | Check required `_meta` keys and capability shapes |
| `404`, `-32601` | Method unsupported | Use discovery/list/call; optional features are absent |
| `200`, `-32602` | Method params/tool selection invalid | Check cursor absence and exact tool name |
| `200` plus `isError: true` | Input, business, execution, or output validation failed | Record only fixed category and tool name |
| Timeout/cancelled | Deadline, idle timer, caller abort, or close won | Check category and request ID; late results are ignored |
| Next `/mcp` is `404`/consumed | Wrong rewrite owner | Verify `next.config`, Pages API route, and `bodyParser: false` |
| WordPress scoped `/mcp` is `404` | Wrong site scope | Use explicit `home_url`-derived URL |

Safely diagnose with a fresh `server/discover`, `tools/list` without a cursor,
then a non-sensitive read-only fixture call. Record only status, result category,
request ID, tool count/names, duration, and terminal category. Run
`make mcp-blackbox` and package-local WordPress tests for regressions. Never use
Relay endpoints as fallback or weaken security and resource limits.
