# MCP 2026-07-28 Phase 1 Scope

Phase 1 migrates Frontman's existing tool workflows to the MCP `2026-07-28`
wire contract. It is not a complete implementation of every capability described
by that contract.

## Authoritative Contract

- Release: `2026-07-28`
- Repository: <https://github.com/modelcontextprotocol/modelcontextprotocol>
- Commit: `5f5440bb26a62e2cf3440b92da5a667efa03b267`
- TypeScript schema: [`schema/2026-07-28/schema.ts`](https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.ts)
- TypeScript SHA-256: `742750af0bb8c716e7030c4977c992b55d1adc4407e9e66997db5846baedc2cd`
- JSON Schema: [`schema/2026-07-28/schema.json`](https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.json)
- JSON Schema SHA-256: `ef70b61f99b6d2e5e3b46863822eab08dff6a45bedc7a08914e0e5b133f40203`

The immutable upstream files are downloaded and checksum-verified when needed.
They are not copied into this repository.

## Supported Methods

Phase 1 implements only:

- `server/discover`
- `tools/list`
- `tools/call`
- `notifications/cancelled`

Tool listing is initially one deterministic page. Tool calls initially return a
synchronous complete result. Frontman does not advertise capabilities it does
not implement.

## Supported Transport

Browser-to-framework communication uses sessionless Streamable HTTP at
`POST /mcp` with synchronous JSON responses.

Phoenix-to-browser communication retains its existing per-task ownership while
adopting the modern wire contract. The custom transport carries the minimum
Frontman execution-context metadata needed to route a tool call.

## Deferred Capabilities

Phase 1 does not include:

- SSE responses
- Protocol sessions
- Pagination or cache retry behavior
- Resources, prompts, sampling, elicitation, roots, or logging
- Generic third-party MCP server compatibility
- Remote schema workers or custom physical headers
- Shared Phoenix connection ownership or failover
- Durable execution claims, leases, fencing, or restart recovery
- Canonical migration of historical tool results
- WordPress transport migration

Deferred capabilities remain absent from advertised capabilities. Unsupported
methods are rejected rather than partially implemented.

## Verification Policy

Every implementation pull request includes focused tests for its supported
behavior. Full upstream examples, property suites, and conformance runners are
downloaded from immutable pins in scheduled or release CI; their corpora,
archives, dependencies, and generated output are not committed to the source
tree.

Generated protocol schemas remain build artifacts. Generator changes and
runtime behavior changes are reviewed separately.

## Completion Criteria

Phase 1 is complete when:

1. Vite, Astro, and Next.js expose the scoped `POST /mcp` endpoint.
2. The browser discovers, lists, and calls framework tools through that endpoint.
3. Phoenix and the browser use the scoped modern contract for browser tools.
4. Cancellation reaches the active tool execution where the host supports it.
5. Relay and initialization-era paths are deleted after their replacements ship.
