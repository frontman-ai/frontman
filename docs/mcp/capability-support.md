# MCP Capability Support

This matrix describes the current MCP `2026-07-28` implementation. It is a
release-review index, not a substitute for the 443-row [normative
traceability](traceability.md) inventory.

## Runtime Matrix

| Capability | JavaScript Streamable HTTP server | WordPress Streamable HTTP server | Browser HTTP client | Browser custom Phoenix server | Phoenix custom-transport client |
| --- | --- | --- | --- | --- | --- |
| `server/discover` | Yes | Yes | Yes | Yes | Yes |
| `tools/list` | One page, deterministic | One page, deterministic | Paginated, bounded | One page, deterministic | Bounded peer catalog |
| `tools/call` | Yes | Yes | Yes | Yes | Yes |
| JSON response | Yes | Yes | Yes | N/A, Phoenix event framing | N/A, Phoenix event framing |
| SSE response consumption | N/A, no producer | N/A, no producer | Yes | N/A | N/A |
| Stream/disconnect cancellation | Node request/response close | No PHP-side guarantee | Fetch/reader abort | Exact `notifications/cancelled` ID | Sends exact cancellation ID |
| Per-request protocol metadata | Required | Required | Sent | Required | Sent |
| `serverInfo` on results | Discovery, list, call, and call errors | Discovery, list, call, and call errors | Informational only | Discovery, list, call, and call errors | Informational only |
| Tool input validation | Sury plus bounded JSON Schema | Registration-validated PHP profile | Bounded Worker | Sury | Validates peer contract |
| Tool output validation | Bounded Worker before response | Result contract; no `outputSchema` producer | Bounded Worker before use | Sury result contract | Invocation-time snapshot before persistence |
| Request rate limit | 256 authenticated POSTs/60 seconds/principal | 256 authenticated supported requests/60 seconds/site-user | N/A | 256 new underlying executions/60 seconds/server plus 256 active executions; exact durable replays do not re-execute | 256 pending client requests; server rate limiting is not a client responsibility |
| Registry/catalog limit | 256 tools; 64 KiB/tool; 1 MiB total | Same | Same assembled bounds | Same browser registry bounds | Rejects over 256 tools |
| Human tool consent | N/A, host policy | N/A, host policy | Host callback before dispatch | First-use read-only session consent; every write/read-write invocation | Relies on browser host decision |
| Protocol sessions | No | No | No | No; Phoenix connection is transport only | No; Phoenix connection is transport only |

## Advertised Server Capabilities

JavaScript and WordPress MCP servers advertise:

```json
{"tools":{"listChanged":false}}
```

The browser custom-Phoenix server advertises `tools: {}` and the required
`ai.frontman/execution-context` extension at version `1`; it does not advertise
`listChanged`.

Resources, prompts, completions, subscriptions, progress emission, MCP Logging,
Roots, Sampling, Elicitation, MRTR fulfillment/retry, OAuth authorization, tasks,
stdio, HTTP+SSE, protocol sessions, and server-side tool pagination are not
advertised or implemented.

Exact absence evidence:

- JavaScript: `FrontmanCore__MCP__Endpoint.test.res` asserts exact capabilities,
  absent optional keys, and absent session/resumption headers;
  `FrontmanCore__MCP__DecodedRequest.test.res` proves `resources/list` returns
  HTTP 404/JSON-RPC `-32601`.
- WordPress: `McpTest.php::test_stateless_identity_and_optional_feature_absence`
  asserts exact capabilities, no session header, unsupported-method `-32601`, no
  side effect, and calls without discovery history.
- Custom Phoenix: `FrontmanClient__MCP.test.res` and `tasks_channel_test.exs`
  constrain directions and implement only discovery, tools, and cancellation.
- Browser OAuth: `FrontmanClient__MCP__OAuthAbsence.test.res` serves a hostile
  `401` `resource_metadata` challenge and proves one original `/mcp` POST with
  zero metadata, well-known, token, or dynamic-registration requests.
- Official conformance: `conformance.md` lists the exact conditional skip
  allowlist; an unexpected skip fails.

## Evidence Boundaries

- The JavaScript and WordPress server slices are implemented and approved, but
  this document does not accept all of Phase 2.
- Applicable official conformance passed with disclosed pinned-runner fixture
  corrections. It is not pristine unmodified-fixture client conformance.
- Provider-backed installed application E2E has not run because
  `test/e2e/.env` is absent. The root aggregate has not passed.
- Browser-host consent is implemented in `Client__ToolConsent`, wired through
  `Client__FrontmanProvider` and `FrontmanClient__MCP__Server.authorizeTool`.
  Unit denial proof shows no framework request; the credentialed E2E helper
  asserts both dialog classes but has not executed without `test/e2e/.env`.
- BlueHotDog reviewed and accepted fixed timeout policy, no separate visible
  cancellation-request state, framework-owned listener binding, and local-host
  sandboxing as SHOULD deviations or residual host responsibilities.
- The whole Phase 10 semantic-review remediation is implemented, including
  direction-specific and focused OAuth absence evidence. It remains pending
  independent rereview passes, while explicit acceptance remains open; this matrix does not infer
  acceptance from implementation status.

See [implementation limits](implementation-limits.md), [endpoint and
authentication](endpoint-auth.md), and [custom Phoenix
transport](custom-phoenix-transport.md).
