# Private Relay Migration

Frontman's private Relay protocol is removed. This is a breaking, latest-only
migration with no compatibility alias.

| Removed | Replacement |
| --- | --- |
| `GET /frontman/tools` | `POST /mcp`: `server/discover`, then `tools/list` |
| `POST /frontman/tools/call` | `POST /mcp`: `tools/call` |
| Bare `event: result` / `event: error` SSE | JSON-RPC in JSON or standard MCP SSE |
| Relay `callId` | JSON-RPC `id`; durable identity is explicit custom-transport metadata |
| Relay tool fields | Standard MCP Tool and annotations |

Every request now carries protocol version and client capabilities in `_meta`.
HTTP also requires `MCP-Protocol-Version`, `Mcp-Method`, and `Mcp-Name` for
`tools/call`. See [endpoint-auth.md](endpoint-auth.md).

## Package Migration

- Replace `FrontmanClient__Relay` with `FrontmanClient__MCP__Client`.
- Replace private SSE parsing with `FrontmanClient__MCP__SSE`.
- Replace Relay definitions with `FrontmanProtocol__MCP.Tool` and complete MCP
  discovery/list/call results.
- Configure framework endpoint security explicitly. Vite and Astro expose no
  `/mcp` endpoint without it.
- For Next.js, run the installer/update path so `next.config` owns the rewrite
  and the generated Pages API route retains `bodyParser: false`. Remove `/mcp`
  from middleware and Proxy matchers.
- For WordPress, use the explicit `home_url`-scoped URL and plugin nonce; do not
  reconstruct the endpoint from the UI pathname.

Calls are stateless and may execute without discovery. Catalogs are deterministic,
private, and bounded. Input failures are complete error tool results; malformed
calls and unknown tools are protocol errors. Successful and error structured
output is checked against the invocation-time `outputSchema`. JavaScript and WordPress
endpoints enforce per-principal rates. Sessions, initialization, deprecated
HTTP+SSE, and private fallback routes are absent.

Package/no-secret checks include:

```text
make -C libs/frontman-protocol mcp-verify
make mcp-blackbox
make mcp-conformance
make check-source-comments
```

`make mcp-verify` is the release aggregate and intentionally fails preflight
without `test/e2e/.env`. Do not report it as passed when only the checks above
pass.
