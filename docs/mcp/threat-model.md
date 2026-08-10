# MCP Threat Model

## Scope

This threat model covers the MCP `2026-07-28` path planned in `plaan.md`:

```text
Phoenix TasksChannel connection owner
-> browser MCP server
-> browser Streamable HTTP client
-> framework /mcp server
-> tool execution
-> canonical validation and persistence
-> ACP and model consumers
```

It also covers browser-local tools, WordPress's independent `/mcp` adapter,
reconnect and durable execution ownership, vendored protocol/conformance artifacts,
and historical result replay. OAuth for remote framework MCP access, MRTR, emitted
progress, subscriptions, and catalog-change polling are not initially implemented.
Adding any of them requires a threat-model update before capability advertisement.

## Assets

| Asset | Security requirement |
| --- | --- |
| Project files and framework state | Prevent unauthorized reads, writes, execution, and duplicate mutation. |
| WordPress content, settings, media, commerce, and authenticated session | Preserve cookie authentication, administrator/tool-specific capabilities, nonce checks, and private caching. |
| Frontman user, organization, task, and agent data | Authorize every operation from server-derived scope; prevent cross-user/task access. |
| Durable tool calls and results | Preserve integrity, provenance, ordering, canonical content, and one terminal resolution. |
| Execution ownership and idempotency identifiers | Permit one active owner and prevent unsafe replay or acceptance from former owners. |
| Provider credentials, cookies, nonces, authorization headers, and tokens | Keep out of URLs, protocol metadata, logs, errors, archives, and unauthorized caches. |
| Tool arguments, source text, screenshots, audio, embedded resources, and structured content | Bound, validate, preserve where required, and avoid unintended disclosure or execution. |
| Tool catalog and schemas | Prevent catalog poisoning, header injection, SSRF, validation denial of service, and authorization inference from annotations. |
| Browser and Phoenix availability | Bound memory, CPU, requests, streams, timers, queues, and retained correlation state. |
| Vendored normative oracle and conformance runner | Preserve provenance and integrity without treating upstream artifacts as trusted executable code. |
| Audit evidence | Record security-relevant outcomes without recording sensitive payloads. |

## Trust Boundaries

| Boundary | Trust decision |
| --- | --- |
| Hostile web origin -> browser-facing framework `/mcp` | The web origin is untrusted. Missing, `null`, malformed, or unlisted Origin is rejected before body processing. Origin is a browser request gate, not authorization. |
| Local process/network -> framework `/mcp` | Loopback reduces exposure but does not authenticate local callers. Browser-facing endpoints require Origin; any future non-browser or remote access requires a separately reviewed authentication policy. |
| Browser -> Phoenix socket and `TasksChannel` | The socket is authenticated, but every browser payload remains untrusted. Phoenix derives user scope and owns task authorization, request correlation, deadlines, and durable ownership references. |
| Phoenix -> browser MCP server | Phoenix requests are authoritative only for the authenticated connection and pending request. The browser must still validate per-request metadata and cannot infer authority from task IDs or client information alone. |
| Browser MCP server -> browser-local tool | The dispatcher authorizes a registered tool and supplies bounded arguments and cancellation. A tool cannot choose its own durable identity or broaden its authorization. |
| Browser HTTP client -> framework MCP server | Discovery, schemas, headers, and results are untrusted in both directions. The framework independently validates Origin, authentication where present, mirrored headers, arguments, and cancellation. |
| Framework handler -> project/WordPress tool | The registry and server-derived execution context determine available capability. Tool names, annotations, and arguments cannot grant additional access. |
| Phoenix process -> PostgreSQL | PostgreSQL is the authority for claims and terminal result uniqueness. Node-local Registry is only waiter routing and cannot establish ownership. |
| Canonical persisted result -> ACP, model, UI, and history replay | Persisted JSON is not trusted merely because it is durable. One validated canonical representation is used by every consumer; migration fails visibly on malformed legacy rows. |
| Repository -> vendored upstream archive | A matching repository checksum proves local consistency, not upstream safety or authenticity. Archives and runners execute only in isolated verification environments. |

## Threats And Mitigations

### Origin And DNS Rebinding

**Threats**

- A hostile website targets a local Vite, Astro, Next.js, or WordPress server and invokes filesystem or application mutation tools.
- DNS rebinding changes a hostile hostname to loopback after page load.
- `Origin: null`, omitted Origin, malformed/multiple values, suffix matching, userinfo, alternate ports, trailing dots, or encoded host forms bypass a permissive comparison.
- Wildcard CORS exposes `/mcp` or the sibling source-location endpoint.

**Mitigations**

- Every browser-facing `/mcp` request requires exactly one syntactically valid Origin matching an explicit scheme/host/effective-port allowlist entry.
- Missing, `null`, malformed, duplicate, or unlisted Origin returns HTTP `403` with an empty body before authentication, body read, JSON parse, or execution.
- Accepted cross-origin responses echo only the validated Origin and set `Vary: Origin`; `/mcp` never uses wildcard CORS.
- Local development servers bind to loopback where adapters permit it.
- `/frontman/resolve-source-location` receives a separately explicit Origin and authorization policy so migration does not leave a sibling disclosure path.
- Host and forwarded-header handling is adapter-owned and must not synthesize an allowed Origin from attacker-controlled values.

### Authentication And Authorization

**Threats**

- Client-supplied user, task, framework, capability, tool annotation, or extension metadata is mistaken for authority.
- A valid user accesses another user's task or reuses a leaked state handle.
- WordPress migration weakens its existing cookie, administrator capability, nonce, or tool-specific capability checks.
- Authorization-sensitive discovery is cached across principals.
- A future bearer-token shortcut accepts tokens issued for another resource or passes tokens through to downstream services.

**Mitigations**

- Phoenix derives `%Scope{}` from the authenticated socket and checks task/tool-call ownership at every context boundary.
- Durable execution claims bind tool call, task, and owning MCP connection; possession of an ID is not authorization.
- WordPress preserves authenticated session, `manage_options`, `X-WP-Nonce`, Playground scope handling, and narrower tool capabilities such as WooCommerce authorization.
- Authorization-sensitive catalog responses use `cacheScope: private` and cache keys include endpoint, authorization context, protocol version, method, and effective parameters.
- Client information, `_meta`, and `ai.frontman/execution-context` are validated protocol context only and never grant permission.
- Remote framework access, if required, implements the complete MCP OAuth protected-resource flow separately. Frontman does not invent bearer-token passthrough or accept tokens for another audience.

### Replay, Duplicate Execution, And Ownership

**Threats**

- Multiple task channels, tabs, Phoenix nodes, reconnects, or blind retries execute one side-effecting tool call more than once.
- Database result uniqueness hides duplicate external effects after they occur.
- A former lease owner returns after takeover and resolves the new owner's request.
- A partition leaves an uncertain non-idempotent mutation running while another owner replays it.

**Mitigations**

- The existing authenticated `TasksChannel` is the sole connection-wide MCP request owner; task channels only observe persisted interactions.
- PostgreSQL atomically claims the durable `tool_call_id` before send. One active owner may send, retry, cancel, renew, or accept a response.
- The browser deduplicates the preserved durable Frontman tool-call identifier.
- The 60-second database-time lease renews every 20 seconds; disconnect attempts immediate release. Takeover uses compare-and-set, and former-owner responses are ignored.
- Result persistence and claim completion are one transaction and produce one terminal result.
- Frontman never automatically replays after uncertain non-idempotent execution. It records that explicit user resolution is required. Automatic retry is allowed only when execution provably did not begin or verified tool-level idempotency is bound to the same durable identifier.

### Cancellation And Timeouts

**Threats**

- Agent, user, timeout, disconnect, or stream closure stops waiting while browser/framework work and side effects continue.
- Completion races cancellation and produces two terminal outcomes.
- Late output is persisted after timeout or claim takeover.
- Interactive browser promises, fetches, stream readers, timers, or resolver callbacks leak across reconnect.

**Mitigations**

- Every sent request has one owner, start timestamp, immutable ten-minute absolute deadline, applicable 60-second idle timer, and cancellation mechanism.
- Phoenix cancellation propagates to the browser `AbortController`; HTTP cancellation aborts fetch and reader; response-stream closure reaches the framework tool context.
- Pending-state removal and terminal transition are atomic. Cancellation is terminal even if underlying work cannot stop.
- A cancelled or completed ID enters bounded late-response tracking. Every non-pending response is unable to resolve another request.
- The question tool permits one unresolved resolver and explicitly rejects or resolves it during cancellation, disconnect, and replacement attempts.

### Resource Exhaustion

**Threats**

- Oversized HTTP/Phoenix messages, deep JSON, metadata, catalogs, schemas, results, or decoded Base64 exhaust memory.
- Pagination loops, recursive references, schema compilation, validation, SSE streams, or silent requests exhaust CPU or connection capacity.
- Many pending or terminal request IDs grow connection state without bound.
- Per-limit valid values combine into an excessive aggregate.

**Mitigations**

- Enforce every byte, depth, count, time, aggregate-media, timeout, cursor, and retention limit in `implementation-limits.md` at the earliest owning boundary.
- Count raw bytes before buffering/decoding and preflight Base64 before incremental decode.
- Catalog publication and result persistence are all-or-nothing; no truncation silently changes semantics.
- Schema work runs in an interruptible Worker or equivalent isolation, not synchronously on the browser main thread.
- Pending requests and concurrent tool execution require separate per-connection and per-principal concurrency/rate limits before release; values must be added to the implementation limits if Phase 0 expands to require them.
- Adapter black-box tests verify disconnect and cancellation release readers, streams, timers, workers, claims, and request context.

### Schema References And Header Injection

**Threats**

- A tool schema causes SSRF through network `$ref`, file access, redirects, DNS rebinding, or authorization/OAuth metadata discovery.
- Recursive/composed schemas consume unbounded validation time.
- Malformed `x-mcp-header` annotations inject headers, disagree with request bodies, or poison an entire catalog.
- A schema validates differently between browser, framework, and model conversion paths.

**Mitigations**

- Generic remote validation supports JSON Schema 2020-12 within documented limits and never fetches network, file, data, or cross-document references.
- Internal fragment references resolve only within the same bounded schema document and remain subject to validation duration and instance JSON-depth limits.
- Invalid explicit dialects and invalid `x-mcp-header` annotations exclude only the affected remote tool, with a payload-free warning.
- Mirrored header values use required ASCII/Base64-sentinel encoding. Framework servers decode and compare every recognized header with the body; mismatch returns HTTP `400` and `-32020 HeaderMismatch` before execution.
- Frontman-owned ReScript tools continue using Sury schemas; the generic untrusted validator is not duplicated into `frontman-core` without an untyped producer.

### Logging And Diagnostics

**Threats**

- Tool arguments, source, credentials, tokens, cookies, nonces, metadata, schemas, screenshots, or media enter normal logs, Sentry, tracing, framework log tools, or user-visible errors.
- Mirrored headers make sensitive arguments visible to intermediaries.
- Error messages become an authorization, filesystem, or network oracle.

**Mitigations**

- Structured logs contain only request correlation ID, authenticated principal ID, task ID, method, tool name, categorical outcome, configured limit, byte/count measurements, and timing.
- Never log request/response bodies, argument values, `_meta` values, schemas, Base64, source content, authorization headers, cookies, or nonces.
- Remove current complete-argument and malformed-argument-prefix logging paths.
- `x-mcp-header` remains an explicit server-authored schema choice; sensitive fields are not annotated. Proxies and tracing suppress `/mcp` payload/header capture.
- Protocol errors expose the minimum stable category and never include rejected data.

### Result Content And Embedded Resources

**Threats**

- Invalid Base64 crashes live delivery or history replay.
- Audio, resource links, embedded resources, empty content, or primitive structured content take divergent paths and bypass validation.
- Embedded data is executed or resource links are dereferenced automatically.
- Modern metadata is stripped or sensitive metadata is retained indefinitely.

**Mitigations**

- One canonical validated result is established before persistence and reused for live delivery, ACP, history, UI, and model conversion.
- Content block count and decoded per-block/result media budgets are enforced before persistence; invalid content produces one bounded canonical protocol-error result.
- Resource links are preserved but never automatically fetched. Embedded content is preserved within limits and never executed.
- Empty content and arbitrary JSON structured content remain valid. Output schema validation is bounded and occurs before persistence.
- Preserve protocol metadata required for replay and caching; redact only explicitly classified sensitive vendor metadata.

### Provenance And Archive Execution

**Threats**

- A compromised upstream release, repository, or refresh process introduces a malicious schema, example, or conformance runner.
- A checksum stored beside an artifact is treated as proof of publisher authenticity.
- Archive path traversal, absolute paths, symlinks, build hooks, or test code overwrite the workspace, read secrets, or access the network.
- Local modification or stale provenance silently changes the normative oracle.

**Mitigations**

- Pin immutable upstream commits, source URLs, versions, licenses, and SHA-256 values; vendor generated schema/examples unchanged and verify offline.
- Review provenance and artifact diffs independently during refresh. A matching checksum proves only equality to the reviewed pin.
- Inspect archive entries before extraction; reject absolute paths, parent traversal, device entries, and escaping symlinks.
- Run conformance code in an isolated, unprivileged environment with no repository write access beyond disposable output, no secrets, bounded resources, and no network.
- The authoritative TypeScript source remains checksum-pinned rather than executed or vendored as authored runtime source.

### Browser And Phoenix Compromise

**Threats**

- XSS or a malicious dependency controls the browser and sends authenticated Phoenix messages or local framework calls.
- A compromised browser fabricates responses, task IDs, capabilities, or durable execution IDs.
- A compromised Phoenix node attempts to claim another principal's work or leaks persisted content.

**Mitigations**

- Treat the browser as an authenticated but untrusted protocol peer. Phoenix validates every response against exact pending ID type, method, owner, deadline, and schema before persistence.
- Server-derived scope and database ownership remain authoritative; browser metadata cannot rebind a tool call to another user or task.
- CSP, dependency review, and avoidance of unsafe URL execution reduce browser compromise risk but do not replace server authorization.
- Multi-node claims use database transactions rather than process identity or node-local Registry.
- A compromised authorized browser may still invoke tools available to that user; high-risk product actions may require additional user confirmation outside core MCP.

## Validation Evidence

### Current Evidence

- The MCP `2026-07-28` TypeScript schema is pinned by immutable URL and SHA-256.
- The generated JSON Schema, 129 official examples, license, and conformance source archive are vendored with checksums under `libs/frontman-protocol/test/mcp-upstream/`.
- Offline checksum, JSON Schema 2020-12 loading, and named official-example validation pass as recorded in `plaan.md`.
- Current architecture and defects are documented in `plaan.md`, including wildcard CORS, duplicate task-channel execution, incomplete cancellation, unsafe logging, partial content handling, and node-local ownership.
- WordPress currently enforces cookie authentication, administrator capability, and POST nonce checks. These controls are migration invariants, not proof that `/mcp` is implemented.

### Planned Release Evidence

- Boundary and one-over-boundary tests for every row in `implementation-limits.md`.
- Shared black-box adapter suite for Vite, Astro, Next.js, and WordPress covering Origin, headers, status codes, malformed JSON, body limits, execution, and cancellation.
- Hostile-Origin tests prove HTTP `403` and zero side effects for missing, `null`, malformed, DNS-rebinding, and unlisted origins.
- Multi-tab, multi-channel, multi-node, disconnect, lease-expiry, former-owner, late-response, and uncertain non-idempotent execution tests.
- Real in-process HTTP tests for discovery, pagination including empty cursors, caching isolation, schema exclusion, JSON/SSE parsing, size limits, timeout, and reader cancellation.
- Canonical result tests for empty content, every standard content block, invalid/oversized media, arbitrary structured JSON, persistence, ACP, live delivery, and history replay.
- Captured-log and Sentry tests prove secret fixtures never appear in normal diagnostics.
- Network-denial tests prove schemas and embedded resource links cause no outbound dereference.
- Isolated archive extraction and conformance execution tests validate path and resource controls.
- Pinned official conformance runner completes with zero failures, expected failures, or skipped applicable cases.
- Independent review follows normative traceability from specification requirement to code and positive/negative tests.

Planned evidence is not current assurance. Frontman must not claim MCP `2026-07-28`
conformance until the release acceptance criteria in `plaan.md` are complete.

## Residual Risks

- Exactly-once non-idempotent side effects cannot be guaranteed across arbitrary network partitions without tool-level idempotency. Explicit user resolution reduces duplicate risk but cannot determine an unknowable external outcome automatically.
- A compromised browser operating with a legitimate user's authority can request actions that user is permitted to perform. Origin validation prevents hostile-origin access, not same-origin XSS.
- Local processes can reach loopback independently of browser Origin rules. Supporting non-browser local callers requires authentication or a separately accepted local trust policy.
- Cancellation cannot reverse a side effect already committed by a tool, and some framework APIs may not be interruptible.
- Browser scheduling, garbage collection, proxies, framework adapters, PHP configuration, and connection buffering can differ from deterministic tests.
- Twelve-megabyte wire responses and eight-megabyte decoded media can still create transient memory amplification from Base64, JSON, canonical persistence, and downstream conversion despite incremental limits.
- JSON Schema implementations may disagree on edge cases, and bounded validation can reject valid but unusually complex third-party schemas.
- Official schemas, examples, and conformance tooling may contain defects or omit prose-only security, timing, and lifecycle requirements.
- A reviewed checksum cannot protect against an upstream compromise that occurred before artifact selection.
- Cross-language implementations may share the same mistaken interpretation; independent upstream and security review remain necessary.
- Third-party proxies, WordPress plugins, framework middleware, and hosting configuration may rewrite Origin, headers, routes, bodies, buffering, or disconnect behavior outside Frontman's control.
- New MCP errata or security guidance may require a deliberate oracle refresh, threat-model update, and release decision.
