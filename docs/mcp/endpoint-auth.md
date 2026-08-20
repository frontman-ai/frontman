# MCP Endpoints And Authentication

Frontman uses two sessionless Streamable HTTP servers and one custom Phoenix
transport. They share MCP messages, but not routing or authentication machinery.

## JavaScript Frameworks

Next.js, Astro, and Vite expose exact `POST /mcp` only when MCP security is
configured. Every POST requires an exact configured HTTP(S) `Origin`,
application authorization, `Content-Type: application/json`, an `Accept` offer
containing JSON and SSE, `MCP-Protocol-Version`, `Mcp-Method`, and `Mcp-Name` for
`tools/call`.

Origin validation precedes authorization. Authorization precedes rate
accounting, media validation, body reading, parsing, and execution. Invalid or
missing Origin returns empty `403`; missing authentication returns empty `401`;
insufficient authorization returns empty `403`. Authenticated POSTs consume the
256-per-60-second principal budget before body reading. Request 257 returns empty
`429` with `Retry-After`; invalid limiter state/capacity returns empty `503`.

Next.js uses an installer-owned `next.config` rewrite to a generated Pages API
route with body parsing disabled. It reads `FRONTMAN_MCP_TOKEN` and
`FRONTMAN_MCP_ALLOWED_ORIGINS`. Do not place `/mcp` in middleware, Proxy, or an
App Router handler; those paths do not preserve the raw body and physical
headers required by the MCP boundary.

Astro and Vite receive equivalent explicit `mcp` security configuration and
register no endpoint when it is absent. Next server rewrites retain the
documented case/trailing-slash normalization limit; Astro and Vite enforce the
exact case-sensitive path.

The Frontman UI response can provision the configured browser MCP credential as
`frontman_mcp_session`, scoped to `/mcp` with `HttpOnly` and `SameSite=Strict`
(`Secure` on HTTPS). The credential is not embedded in UI HTML or exposed to
JavaScript. `FrontmanCore__Middleware.withMcpBrowserCookie` owns serialization;
`FrontmanCore__Middleware.test.res` proves encoding, scope, flags, and HTML
absence. The accepted cookie is also an authorization-specific rate principal.

## WordPress

WordPress exposes exact root or `home_url`-scoped `/mcp`. A POST requires the
exact site Origin, an authenticated WordPress session, `manage_options`, and a
valid nonce. Missing session returns `401`; capability or nonce failure returns
`403`.

Every request requires `MCP-Protocol-Version` and `Mcp-Method`. Method-based
authority additionally requires `Mcp-Name` for `tools/call` and `prompts/get`
from `params.name`, and for `resources/read` from `params.uri`. Presence is
checked before mirrored values and malformed named-method parameters cannot
bypass the required-name/header-mismatch classification.

Rate accounting is keyed to `wordpress:{blog ID}:user:{user ID}` after
authorization. Only a SHA-256 digest is stored in a non-autoloaded option. The
limit is 256 supported requests per 60 seconds. PHP buffering means Node chunk,
idle/absolute deadline, streaming commitment, and disconnect-abort guarantees
do not apply; the hosting server owns those limits.

WordPress authentication is application authentication. It does not advertise
or partially implement the MCP OAuth profile.

## Browser HTTP Client

`FrontmanClient__MCP__Client` sends a fresh POST for every message. Caller
headers are copied while mandatory MCP headers override conflicts. Private
catalogs are isolated by endpoint and authorization context. The client accepts
JSON and standard SSE, enforces response, pagination, catalog, schema, idle, and
absolute limits, and never uses `Mcp-Session-Id` or `Last-Event-ID`.

The client does not implement MCP OAuth discovery, token exchange, or dynamic
registration. Focused runtime evidence serves a hostile `401` Bearer
`resource_metadata` challenge and observes exactly one original `/mcp` POST with
zero metadata, well-known, token, or registration requests.

## Custom Phoenix Transport

The authenticated Phoenix socket/channel authorizes the transport. MCP metadata
is never an authorization source. See
[custom-phoenix-transport.md](custom-phoenix-transport.md).

Preflight validates Origin and requested method/headers but does not authenticate
or consume a rate budget. Responses echo only the validated Origin, never `*`,
and include `Vary`. `/frontman/resolve-source-location` has a separate Origin-only
policy and must not inherit MCP credentials.
