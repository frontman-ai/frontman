# MCP 2026-07-28 Alignment Plan

## Purpose

Frontman will migrate aggressively and atomically to Model Context Protocol (MCP) specification version `2026-07-28`.

The target is a latest-only implementation:

- No support for initialization-era MCP versions.
- No `initialize` or `notifications/initialized` handshake.
- No `Mcp-Session-Id` protocol sessions.
- No fallback to the private Frontman relay protocol.
- No deprecated HTTP+SSE transport.
- Browser-to-framework communication uses standard MCP Streamable HTTP at `POST /mcp`.
- Phoenix-to-browser communication uses MCP over a documented custom Phoenix transport.
- Frontman advertises only capabilities it implements and validates completely.

This document is the implementation plan, specification traceability starting point, test strategy, and release acceptance contract.

Absolute absence of defects cannot be mathematically proven. The release standard is independently validated conformance, exhaustive coverage of applicable normative requirements, zero accepted conformance failures, explicit implementation limits, and documented residual risks.

## Implementation Status

Last updated: `2026-08-10`.

| Milestone | Status | Evidence or blocker |
| --- | --- | --- |
| Repository-wide comment-removal implementation | Merged | Cleanup, source-aware scanner, scanner tests, Make target, Lefthook hook, CI job, Credo alignment, and Makefile help preservation are on `main`. |
| Repository-wide comment-removal acceptance | Accepted | WordPress core-tool and runtime tests passed, followed by the source scan, generated-schema diff check, and `git diff --check`. |
| Phase 0 normative oracle and traceability | Accepted | The immutable upstream schema, 129 official examples, license, and checksum-pinned conformance archive are vendored. Offline checksums, JSON Schema 2020-12 validation, and structural verification of 443 unique normative traceability requirements pass. Concrete limits, exact boundary vectors, threat model, and initial-scope decisions are frozen. |
| Phase 1 shared MCP wire contract | Accepted | Shared/custom-Phoenix consumers use modern per-request metadata, discovery, tools listing/calling, named errors, complete results, and `ai.frontman/execution-context`; initialization-era MCP schemas and duplicate modern exports are deleted. The serial protocol/client/core/server gate passes, deterministic differential tests pass the 1,000-case pull-request and 10,000-case scheduled profiles locally, the larger profile is configured for scheduled CI, and the pinned generated-schema `JSONValue` defect is recorded as an explicit authoritative-TypeScript exception. Actual cancellation abort belongs to later runtime work. |
| Phases 2-12 | Not started or not accepted | Phase 1 establishes the accepted shared/custom-Phoenix contract but does not complete Streamable HTTP transport or later application behavior. |

The prerequisite implementation and protocol migration remain separate atomic changes. The earlier presence of in-progress modern protocol artifacts was not Phase 0 evidence; Phase 0 is accepted only through the pinned oracle, complete traceability inventory, frozen limits, threat model, verification targets, and acceptance record below. Phase 1 is accepted as the shared/custom-Phoenix contract checkpoint. The complete product migration remains unreleasable until its owning later phases replace the private HTTP relay with Streamable HTTP and finish runtime behavior.

### 2026-08-09 Session Delta

This session completed the Phase 1 consumer cutover and evidence slice without starting Streamable HTTP:

1. The browser custom Phoenix dispatcher and temporary Phoenix TaskChannel exchange modern request metadata, `server/discover`, `tools/list`, `tools/call`, modern named errors, and explicit `ai.frontman/execution-context` values. Browser cancellation receipt is structurally validated, but correlation and work abortion remain later runtime work.
2. Initialization-era MCP schemas and duplicate modern contract artifacts were deleted after consumers moved to the in-place owners. Complete `resultType`, structured content, and open top-level values survive Phoenix persistence and replay, while result `_meta` is scrubbed before storage so provider credentials cannot return through `get_tool_result`.
3. `libs/frontman-protocol/test/fixtures/mcp-phase1-parity.json` supplies one deterministic value set for discovery request/result, list request/result, context-bearing call, complete result, named error, cancellation, and string/numeric IDs. The final serial evidence is `115` protocol verifier tests, all `129` official examples, all `443` traceability requirements, `94` frontman-client tests, `321` frontman-core tests, `319` client tests, and `730` server tests.
4. A major changeset covers only `@frontman-ai/frontman-protocol` and `@frontman-ai/frontman-client` for the latest-only shared/custom-Phoenix contract break.

At the end of the `2026-08-09` slice, deterministic broad differential/property coverage and the final acceptance review remained. The `2026-08-10` acceptance delta below closes those Phase 1 blockers; actual cancellation abort remains later runtime work. `FrontmanProtocol__MCP.protocolVersion` matches the modern contracts and Elixir producer at `2026-07-28`.

### 2026-08-10 Phase 1 Acceptance Delta

1. `VerifyMcpProperty.test.mjs` deterministically generates locally accepted IDs, progress tokens, cancellation IDs, icon themes, audiences, resource sizes, object-rooted tool input schemas, tool arguments, structured content, and metadata key/byte boundaries. Every accepted value round-trips through the Sury runtime schema and validates through the generated schema and named upstream definition.
2. The property suite also deletes generated required fields across request metadata, cancellation parameters, Tool, tools/call parameters, and complete tool results. Existing focused tests retain complete wrong-type, required-field, open-field, and authoritative-artifact discrepancy matrices.
3. Pull-request verification runs `1,000` cases with seed `20260728`. `.github/workflows/mcp-property.yml` verifies the checksum-pinned oracle and runs `10,000` cases weekly or on manual dispatch. Upstream validators are compiled once per named definition so the larger deterministic replay remains bounded and completes locally in under two seconds.
4. The recursive `JSONValue` discrepancy is resolved by explicit source precedence: where the checksum-pinned generated JSON Schema contradicts the authoritative TypeScript schema and rendered specification by rejecting recursive null or fractional values, Frontman follows the authoritative type and keeps an exact test proving the known generated-artifact rejection.
5. Final cleanup searches found no `MCP20260728`, initialization-era MCP schema, old MCP version, required wire `callId`, silent MCP `Suspended`, unnamespaced MCP policy field, or object-only structured-content assumption in active consumers or generated modern schemas. ACP initialization is intentionally unrelated; private Relay policy fields remain only in Relay artifacts scheduled for removal in Phases 2-3.
6. Final protocol evidence is `116` verifier tests, all `129` official examples, all `443` traceability requirements, a local execution of the configured `10,000`-case scheduled profile, stable repeated generation of all `85` schemas, the `30`-test source-comment gate, and `git diff --check`.

## Governing Implementation Rules

These rules apply to every phase and override narrower checklist wording:

1. Fix every repository instance of a defect or changed pattern in the same atomic migration. Search `apps/`, `libs/`, `test/`, `scripts/`, `.github/`, generated artifacts, installer templates, fixtures, and documentation before declaring a pattern complete.
2. Solve behavior at the lowest shared layer used by every affected path. Reuse existing protocol, registry, execution, persistence, channel, adapter, and test helpers before adding another abstraction.
3. Replace legacy code in place wherever practical. Do not create a parallel modern contract, broker, transport stack, compatibility module, feature flag, or fallback when the migration can update the existing owner and delete obsolete code.
4. Keep framework packages independent except for sanctioned shared chassis. Protocol-neutral Node/Web request bridging belongs in shared bindings or core chassis; framework routing, registries, and behavior remain package-local.
5. Do not implement optional MCP features without a current caller. Accept required interoperable inputs, but do not advertise or build production machinery for progress, MRTR, emitted SSE, subscriptions, catalog pagination, or optional capabilities until Frontman uses them.
6. Leave no comments in tracked authored repository source: no source comments, docblocks, TODO/FIXME notes, lint/type suppressions, or commented-out code. Platform-required executable directives remain only where the runtime or toolchain consumes their comment syntax and no comment-free equivalent exists; current approved forms are interpreter shebangs, the leading WordPress plugin metadata header, and TypeScript triple-slash reference directives. Standalone prose, licenses, protocol examples, and immutable data are not source comments. Generated artifacts and build outputs are outside this comment policy and may contain comments. Do not vendor upstream source files that contain comments. Complete repository-wide authored-source comment removal as a separate prerequisite change before protocol implementation, then enforce a repository-wide zero-comment gate throughout the migration.
7. Preserve rationale in commits, pull requests, tests, traceability documents, and this plan rather than source comments.
8. Every phase ends with deletion of superseded code and a repository-wide search for sibling patterns. A phase is incomplete while legacy branches or equivalent unfixed call sites remain.

## Authoritative Standard

The official `2026-07-28` specification and schema are the source of truth. Frontman-generated schemas and types are implementation artifacts, not independent evidence of compliance.

### Primary References

- Release announcement: https://blog.modelcontextprotocol.io/posts/2026-07-28/
- Specification index: https://modelcontextprotocol.io/specification/2026-07-28
- Changelog from `2025-11-25`: https://modelcontextprotocol.io/specification/2026-07-28/changelog
- Base protocol: https://modelcontextprotocol.io/specification/2026-07-28/basic
- Versioning and compatibility: https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning
- Architecture: https://modelcontextprotocol.io/specification/2026-07-28/architecture
- Schema reference: https://modelcontextprotocol.io/specification/2026-07-28/schema
- Authoritative TypeScript schema pinned by immutable URL and checksum but not vendored because its source comments would violate the repository rule: https://github.com/modelcontextprotocol/modelcontextprotocol/blob/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.ts
- Generated JSON Schema used for validation tooling: https://github.com/modelcontextprotocol/modelcontextprotocol/blob/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.json
- Official conformance project: https://github.com/modelcontextprotocol/conformance
- Documentation index: https://modelcontextprotocol.io/llms.txt

### Transport References

- Transport overview and custom transports: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports
- Streamable HTTP: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http
- Standard input/output transport: https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio
- Cancellation: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation
- Progress: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/progress
- Subscriptions: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/subscriptions

### Server Feature References

- Server discovery: https://modelcontextprotocol.io/specification/2026-07-28/server/discover
- Tools: https://modelcontextprotocol.io/specification/2026-07-28/server/tools
- Caching: https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/caching
- Pagination: https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/pagination
- Resources: https://modelcontextprotocol.io/specification/2026-07-28/server/resources
- Prompts: https://modelcontextprotocol.io/specification/2026-07-28/server/prompts
- Logging: https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/logging

### Interaction And Extension References

- Message pattern overview: https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns
- Multi Round-Trip Requests (MRTR): https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr
- Elicitation: https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation
- Extensions overview: https://modelcontextprotocol.io/extensions/overview
- Tasks extension: https://modelcontextprotocol.io/extensions/tasks/overview
- MCP Apps extension: https://modelcontextprotocol.io/extensions/apps/overview
- Deprecated features: https://modelcontextprotocol.io/specification/2026-07-28/deprecated
- Feature lifecycle policy: https://modelcontextprotocol.io/community/feature-lifecycle

### Authorization And Security References

- Authorization: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization
- Authorization server discovery: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/authorization-server-discovery
- Client registration: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration
- Authorization security considerations: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/security-considerations
- Security best practices: https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices
- Authorization tutorial: https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/authorization

### Relevant Specification Enhancement Proposals

- SEP-2106, JSON Schema 2020-12: https://modelcontextprotocol.io/seps/2106-json-schema-2020-12
- SEP-2133, Extensions: https://modelcontextprotocol.io/seps/2133-extensions
- SEP-2243, HTTP header standardization: https://modelcontextprotocol.io/seps/2243-http-standardization
- SEP-1302, input validation errors as tool execution errors: https://modelcontextprotocol.io/seps/1302-input-validation-errors-as-tool-execution-errors
- SEP-2322, Multi Round-Trip Requests: https://modelcontextprotocol.io/seps/2322-MRTR
- SEP-2549, caching TTL: https://modelcontextprotocol.io/seps/2549-TTL-for-list-results
- SEP-2567, sessionless MCP: https://modelcontextprotocol.io/seps/2567-sessionless-mcp
- SEP-2575, stateless MCP: https://modelcontextprotocol.io/seps/2575-stateless-mcp
- SEP-2577, deprecating Roots, Sampling, and Logging: https://modelcontextprotocol.io/seps/2577-deprecate-roots-sampling-and-logging
- SEP-2596, feature lifecycle and deprecation: https://modelcontextprotocol.io/seps/2596-spec-feature-lifecycle-and-deprecation
- SEP-2663, Tasks extension: https://modelcontextprotocol.io/seps/2663-tasks-extension
- SEP-414, OpenTelemetry request metadata: https://modelcontextprotocol.io/seps/414-request-meta

## Current Architecture And Gaps

Frontman currently has two MCP-related boundaries:

```text
Phoenix server acting as MCP client
    |
    | JSON-RPC carried by Phoenix event `mcp:message`
    v
Browser acting as MCP server
    |
    | Custom GET/POST relay with bare SSE result events
    v
Next.js / Astro / Vite / WordPress framework integration
```

The current implementation is not MCP `2026-07-28`:

- Phoenix advertises `DRAFT-2025-v3`.
- ReScript advertises `2025-11-25`.
- The peers perform `initialize` and `notifications/initialized`.
- Requests omit required per-request `_meta` protocol fields.
- Successful results omit required `resultType`.
- The browser does not implement mandatory `server/discover`.
- `tools/list` omits `ttlMs`, `cacheScope`, and pagination behavior.
- `tools/call` requires nonstandard `callId`.
- Tool definitions expose unnamespaced `access`, `visibleToAgent`, and `executionMode` fields.
- `structuredContent` accepts only JSON objects, not arbitrary JSON values.
- Framework endpoints are a custom relay, not Streamable HTTP MCP.
- Framework tool endpoints use wildcard CORS and lack required Origin validation.
- Cancellation does not terminate browser or framework work.
- Multiple task channels can execute the same side-effecting tool call.
- Tool-result conversion does not support every standard MCP content type.
- Tool-result persistence strips modern lifecycle fields and metadata before history replay.
- Historical tool-result reconstruction repeats the empty-content, text/image-only, and raising Base64 behavior found in live execution.
- MCP and relay behavior also remains embedded in generated Phoenix browser-test assets, installer fixtures, CI path filters, and framework-specific route consumers.

## Detailed Current Implementation Audit

This section records the repository research that produced the migration plan. Line references describe the current implementation and must be refreshed if code moves before migration work begins.

The audit below remains the pre-migration baseline. The in-progress Phase 1 delta is recorded under the Phase 1 implementation record rather than rewriting baseline findings as if the atomic migration were complete.

### Phoenix And Elixir Findings

#### Protocol construction

`apps/frontman_server/lib/model_context_protocol.ex` is the Phoenix-side MCP protocol helper.

- Line 27 advertises the nonstandard version `DRAFT-2025-v3`.
- Lines 75-86 construct legacy initialization parameters.
- Lines 94-107 parse only the existing result conventions.
- Lines 109-123 construct `tools/call` with integer JSON-RPC IDs and required `params.callId`.
- Lines 115-122 log complete tool arguments at normal information level, potentially exposing source, credentials, user content, or tokens.

`apps/frontman_server/lib/json_rpc.ex` provides generic JSON-RPC parsing and construction.

- Lines 82-133 parse result and error responses.
- Lines 142-188 build responses, errors, notifications, and requests.
- Current runtime tool response routing accepts only integer IDs even though shared protocol parsing recognizes strings.
- Invalid MCP responses currently cause the channel to send a nonstandard notification whose method is `error` instead of resolving or failing the pending request locally.

#### Legacy initialization state machine

`apps/frontman_server/lib/frontman_server_web/channels/task_channel/mcp_initializer.ex` owns the current handshake.

- Lines 36-57 send `initialize` and establish connection-scoped state.
- Lines 59-110 correlate initialization responses and errors.
- Lines 112-130 send `notifications/initialized` followed by `tools/list`.
- Lines 132-140 convert the first tools page and ignore `nextCursor`.
- Lines 149-196 call `load_agent_instructions` as an initialization step.
- Lines 198-257 call `list_tree` as an initialization step.
- Lines 272-295 emit `mcp_initialization_complete` and mark the task channel ready.
- There is no deadline for any initialization request.
- Response maps and individual tool definitions are not validated against the shared or official schemas before use.
- Project-rule list members and workspace members can trigger pattern-match or map-operation failures when malformed.

The modern migration removes this module's protocol role. Project-context loading becomes ordinary application work after discovery.

#### Task channel transport and request correlation

`apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex` currently combines ACP session work, MCP client state, MCP transport, discovery, recovery, and execution routing.

- Lines 38-75 create a separate MCP session and pending-request map for every joined task channel.
- Lines 118-140 parse browser responses and send the nonstandard `error` notification for invalid responses.
- Lines 143-148 push the deferred legacy initialization request.
- Lines 163-185 receive task interactions through PubSub.
- Lines 222-258 route every MCP-classified persisted `ToolCall` received by that channel to the browser.
- Lines 345-405 distinguish initialization responses from tool responses and correlate integer request IDs.
- Lines 408-445 persist successful tool results and publish ACP updates.
- Lines 475-540 handle JSON-RPC errors and convert them to tool errors.
- Lines 898-905 refuse to wake the agent while MCP initialization remains pending.
- Lines 922-967 apply initialization completion or failure.
- Lines 969-999 redispatch unresolved tool calls after reconnect.
- Lines 1001-1026 build and remember `tools/call` requests.

Because Phoenix automatically subscribes each channel process to its topic, every task channel receives task PubSub interactions. `apps/frontman_server/lib/frontman_server/tasks.ex:249-264` broadcasts persisted interactions to that topic. Multiple joined channels therefore execute the same side-effecting MCP tool. The unique tool-result database constraint deduplicates persistence only after external effects have already occurred.

The pending map stores only `request_id => tool_call_id`. It does not record request kind, method, owner, deadline, cancellation state, or enough bounded recent-ID state to reject duplicate and late responses.

#### Tool execution and persistence

`apps/frontman_server/lib/frontman_server/tasks/execution/tool_executor.ex` bridges LLM tool calls to MCP execution.

- Lines 131-143 register the waiting executor before publishing the MCP tool call.
- Lines 145-190 persist timeout and sibling-cancellation outcomes.
- Lines 193-207 convert only text and image content into model tool-result content.
- Lines 209-227 use a node-local Registry to connect persisted results to the waiting executor.
- Lines 238-249 log the first 500 bytes of malformed arguments, creating a second sensitive-payload logging path beyond the normal MCP call log.

Timeout handling does not notify the MCP transport, remove the channel's pending correlation entry, abort browser execution, or abort a framework HTTP request.

`apps/frontman_server/lib/frontman_server/tasks/execution.ex` delivers recorded results.

- Lines 142-154 only notify a waiting executor when `content` is a non-empty list of maps.
- A valid `content: []` result is persisted but reported as having no executor.
- Lines 156-164 synchronously map each content block before delivery.
- Lines 241-244 support only text and image.
- Audio, resource links, and embedded resources trigger a function-clause failure.
- Invalid image Base64 raises through `Base.decode64!/1`.

`apps/frontman_server/lib/frontman_server/tasks/interaction.ex` persists results and reconstructs historical model messages.

- Lines 920-935 retain only `content`, `structuredContent`, and `isError`, replace `_meta`, and discard modern fields such as `resultType`.
- Lines 1133-1140 accept only non-empty content, so a persisted valid `content: []` result cannot be reconstructed.
- Lines 1170-1174 duplicate the text/image-only conversion and raising Base64 decode used by live delivery.
- Persistence, live executor delivery, historical reconstruction, ACP presentation, and model conversion therefore need one canonical validated result representation rather than separate partial converters.

`apps/frontman_server/lib/frontman_server/tasks.ex` persists and resolves tool interactions.

- Lines 665-673 persist client-handled tool calls and broadcast them.
- Lines 686-734 persist results before notifying a waiting executor.
- Lines 708-725 deduplicate repeated result persistence.
- Lines 754-780 locate unresolved active-run tool calls for reconnect.

Persist-before-notify protects durability, but malformed yet persisted content can repeatedly fail delivery. Result schema validation must happen before persistence or produce a canonical protocol-error result that is itself safe to persist.

#### Tool discovery conversion

`apps/frontman_server/lib/frontman_server/tools/mcp.ex` converts browser tool definitions into agent tools.

- Lines 12-20 define the reduced internal tool representation.
- Lines 22-47 derive local timeout policy from the nonstandard `executionMode` field.
- Lines 28-40 accept missing or malformed tool fields without upstream-schema validation.
- Lines 54-56 map every returned entry.
- Lines 58-72 filter hidden tools and create Swarm tools.

The parser drops standard fields such as title, icons, annotations, and metadata. It accepts arbitrary `inputSchema` and `outputSchema` values without proving JSON Schema 2020-12 validity.

#### Phoenix tests affected

- `apps/frontman_server/test/model_context_protocol_test.exs`
- `apps/frontman_server/test/protocols/mcp_contract_test.exs`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel/mcp_initializer_test.exs`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_sentry_test.exs`
- `apps/frontman_server/test/frontman_server/tools/mcp_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/mcp_tool_routing_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/mcp_tool_broadcast_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/tool_executor_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution/tool_error_sentry_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/tool_result_concurrency_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution_image_history_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/execution_test.exs`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`
- `apps/frontman_server/test/agent_client_protocol/content_test.exs`
- `apps/frontman_server/test/protocols/acp_history_test.exs`
- `apps/frontman_server/test/support/channel_case.ex`
- `apps/frontman_server/test/support/protocol_schema.ex`

Existing server tests strongly cover the legacy handshake, reconnect ordering, persistence, and single-channel routing. They do not currently prove modern metadata, discovery, result retention, cancellation propagation, every content type across live and historical paths, primitive structured content through ACP, or single execution across multiple channels.

### Browser MCP Server Findings

#### JSON-RPC dispatcher

`libs/frontman-client/src/FrontmanClient__MCP.res` is the browser MCP server's transport dispatcher.

- Lines 24-64 distinguish request and notification by presence of `id`.
- Lines 66-84 send success and error responses through `mcp:message`.
- Lines 86-104 implement legacy `initialize` while ignoring request parameters.
- Lines 106-120 implement non-paginated `tools/list`.
- Lines 122-170 parse `tools/call`, require `callId`, and execute the tool.
- Lines 150-159 permit `Suspended` to send no response.
- Lines 172-200 dispatch only initialize, list, and call methods.
- Unknown notifications are silently ignored.
- A top-level exception is logged but does not guarantee a response for a request whose ID was already parsed.
- Lines 202-223 attach and detach the handler from a Phoenix channel.

The browser supports string request IDs in its parsing and tests, while the Phoenix client routes runtime results only for integer IDs.

#### Browser tool registry and execution

`libs/frontman-client/src/FrontmanClient__MCP__Server.res` combines browser-local and relayed tools.

- Lines 20-40 construct the server with local registry, relay, and attachment resolution.
- Lines 46-85 register and serialize local tools.
- Lines 101-137 validate and execute browser-local tools.
- Lines 139-182 rewrite attachment references.
- Lines 186-238 dispatch local tools before relayed tools.
- Lines 240-251 build the legacy initialization result.
- Lines 253-256 return only `{tools}` for `tools/list`.

Local-first dispatch silently hides a remote tool with the same name. The latest Tools specification says aggregated clients should implement an explicit disambiguation strategy. The migration must either reject collisions or namespace tools deterministically.

Attachment rewriting is hard-coded to `write_file` and `wp_upload_media`, coupling tool names across packages instead of using documented schema or extension metadata.

Tool execution receives `taskId` from `handler.sessionId`, not the MCP request. `libs/frontman-client/src/FrontmanClient__ACP.res:306-349` installs one MCP handler per task channel and supplies the ACP session ID as MCP execution context. This violates modern stateless request semantics once Frontman claims `2026-07-28`.

#### Browser tool inventory

`libs/client/src/Client__ToolRegistry.res` registers browser tools:

- `take_screenshot`
- `execute_js`
- `set_device_mode`
- `get_interactive_elements`
- `interact_with_element`
- `get_dom`
- `search_text`
- `question`
- Optional Astro browser audit tooling

These tools expose internal policy fields that must move to standard annotations and a negotiated Frontman extension.

#### Interactive question lifecycle

`libs/client/src/tools/Client__Tool__Question.res:53-90` returns a promise that remains unresolved until UI state invokes stored resolver callbacks.

`libs/client/src/state/Client__Task__Reducer.res:1185-1197` replaces `pendingQuestion` whenever another `QuestionReceived` action arrives. A reconnect redispatch can overwrite the prior callbacks without resolving or rejecting the original promise. Cleanup removes channel listeners but does not abort the old tool promise.

The initial migration keeps this browser-local call and must make it fully cancellable, reconnect-safe, and unable to overwrite an unresolved resolver. Elicitation and MRTR remain a separate future feature.

#### Connection reducer contradiction

`libs/client/src/Client__ConnectionReducer.res` documents relay failure as nonfatal but behaves otherwise.

- Lines 182-199 expose `RelayError` as user-facing `Error`.
- Lines 267-277 call relay failure nonfatal because browser tools remain available.
- Lines 307-318 allow new session creation only when relay state is `RelayConnected`.
- Line 390 rejects every other `CreateSession` state.
- Lines 342-365 load persisted tasks without the same relay-connected requirement.

This is an application defect independent of protocol version. The new HTTP MCP client must define whether browser-only operation is allowed and test session creation accordingly.

#### Browser tests affected

- `libs/frontman-client/test/FrontmanClient__MCP.test.res`
- `libs/frontman-client/test/FrontmanClient__JsonRpc.test.res`
- `libs/frontman-client/test/FrontmanClient__Relay.test.res`
- `libs/frontman-client/test/FrontmanClient__SSE.test.res`
- `libs/frontman-client/test/FrontmanClient__ACP__Client.test.res`
- `libs/client/test/Client__ToolRegistry.test.res`
- `libs/client/test/Client__ConnectionReducer.test.res`
- `libs/client/test/Client__Task.test.res`
- `libs/client/test/Client__RelayBaseUrl.test.res`
- `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Registry.test.res`
- `libs/frontman-astro-browser/test/FrontmanAstroBrowser__Tool__GetAstroAudit.test.res`

Current browser MCP tests cover successful calls, malformed params, method-not-found, exceptions, error codes, and string ID echoing. They do not cover per-request metadata, discovery, result types, cancellation, custom transport teardown, listener ownership, or high-concurrency response isolation. The replacement HTTP client also needs separate remote pagination, cache, and SSE interoperability coverage.

`libs/frontman-client/src/FrontmanClient__ACP.res` currently installs MCP listeners during task-session creation and removes all listeners for the event during cleanup. The channel binding cannot remove one listener by reference. Moving MCP ownership requires updating this shared listener lifecycle and testing multiple listeners, task teardown, and connection teardown so ACP cleanup cannot remove the connection-wide MCP handler.

Relay replacement also affects direct consumers outside the connection reducer:

- `libs/client/src/Client__FrontmanProvider.res` constructs, injects, and disconnects the relay.
- `libs/client/src/components/frontman/Client__UpdateBanner.res` reads relay server information to determine framework package versions.
- `libs/client/src/Client__RelayBaseUrl.res` constructs WordPress Playground-scoped endpoints.

The Streamable HTTP client must preserve these product behaviors through explicit modern interfaces rather than leaving stale Relay dependencies or silently disabling update notifications.

### Current HTTP Relay Findings

#### Relay protocol

`libs/frontman-protocol/src/FrontmanProtocol__Relay.res` defines a private protocol version `1.0`.

- Lines 8-17 define custom remote tool fields.
- Lines 19-25 define a custom discovery response.
- Lines 27-32 define a custom `{name, arguments}` call body.
- Lines 34-36 reuse MCP-shaped result values without JSON-RPC envelopes.

The relay is not the deprecated MCP HTTP+SSE transport and is not modern Streamable HTTP. It is an application-private transport carrying MCP-shaped data.

The workspace also contains an in-progress parallel `FrontmanProtocol__MCP20260728.res` export, generated schemas, fixtures, and conformance tests while the active `FrontmanProtocol__MCP.res` remains legacy. The parallel types are over-permissive in request IDs, progress and cancellation tokens, icon themes, audiences, MRTR values, resource sizes, and tool schema roots, while selected-fixture tests do not prove equivalence with the upstream accepted domain. Treat these artifacts as migration input only: fold correct definitions into the existing shared modules, add differential tests, update every consumer, and delete the parallel API in Phase 1.

#### Relay client

`libs/frontman-client/src/FrontmanClient__Relay.res` implements the browser side.

- Lines 38-88 issue `GET /frontman/tools`.
- Lines 60-68 parse but do not enforce the returned relay `protocolVersion`.
- Lines 96-120 convert remote tools into the browser's MCP catalog.
- Lines 130-188 issue `POST /frontman/tools/call`.
- Lines 147-160 request only `text/event-stream`, not both required modern response media types.
- Tool execution fetch has no abort signal or timeout.

The modern client must replace this module's wire behavior rather than renaming its existing requests.

#### SSE parser

`libs/frontman-client/src/FrontmanClient__SSE.res` parses private relay events.

- Lines 22-43 parse blocks by LF lines.
- Lines 45-64 treat `event: error` data as an opaque error string.
- Lines 88-130 split complete events only on `\n\n`.
- CRLF event streams are not recognized correctly.
- A terminal event without a trailing blank line is discarded at EOF.
- SSE comments and modern complete JSON-RPC message envelopes are not supported.
- Stream cancellation is not propagated through the reader.

#### Relay server

`libs/frontman-core/src/FrontmanCore__RequestHandlers.res` implements the shared framework handlers.

- Lines 53-68 return custom relay tool discovery.
- Lines 70-141 parse a custom call body and always create a custom SSE response.
- Line 76 parses JSON before the validation catch block; malformed JSON syntax can reject the handler and become an adapter-level 500.
- Lines 112-118 emit tool-not-found, invalid-input, and execution errors as custom SSE error events.
- Lines 123-135 catch rejected tool promises and emit another custom error event.
- The source-location handler has the same JSON-before-validation defect at line 148 and must use the same shared body decoder.

`libs/frontman-core/src/FrontmanCore__SSE.res` serializes bare results:

- Lines 17-24 emit `event: result` with a bare CallToolResult.
- Lines 26-33 emit `event: error` with a complete CallToolResult encoded as data.

The browser reads an error event as a string and wraps it in another CallToolResult. Agents therefore receive serialized JSON as error text instead of the original typed error.

#### Relay security

`libs/frontman-core/src/FrontmanCore__CORS.res:4-8` sets:

```text
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

`libs/frontman-core/src/FrontmanCore__Middleware.res:164-180` applies these headers to framework tool and source-location endpoints.

`libs/frontman-core/src/FrontmanCore__ToolRegistry.res:16-28` registers project filesystem tools including read, write, edit, grep, and tree operations.

`libs/frontman-core/src/tools/FrontmanCore__Tool__WriteFile.res:73-108` resolves project paths and can create or overwrite files after its read-before-write guard.

Any hostile origin able to reach the development server can attempt cross-origin project operations. Modern Streamable HTTP explicitly requires Origin validation to address DNS rebinding.

The migration must separately define the Origin and CORS policy for `/frontman/resolve-source-location`. It shares the wildcard policy and malformed-JSON pattern but is not an MCP endpoint, and changing only `/mcp` would leave an information-disclosure sibling unfixed.

#### Relay tests affected

- `libs/frontman-core/test/FrontmanCore__RequestHandlers.test.res`
- `libs/frontman-core/test/FrontmanCore__Middleware.test.res`
- `libs/frontman-core/test/FrontmanCore__SSE.test.res`
- `libs/frontman-core/test/FrontmanCore__CORS.test.res`
- `libs/frontman-core/test/FrontmanCore__ToolRegistry.test.res`
- `libs/frontman-core/test/FrontmanCore__Server.test.res`, if added or present during migration
- `libs/frontman-client/test/FrontmanClient__Relay.test.res`
- `libs/frontman-client/test/FrontmanClient__SSE.test.res`

Current CORS tests explicitly assert wildcard Origin behavior. These assertions must be replaced with absent, allowed, denied, preflight, and credential-sensitive Origin cases.

### Framework Integration Findings

Vite, Astro, and Next.js share `frontman-core` tool execution and therefore inherit the relay protocol and security behavior.

#### Next.js

Relevant files:

- `libs/frontman-nextjs/src/FrontmanNextjs__Middleware.res`
- `libs/frontman-nextjs/src/FrontmanNextjs__Server.res`
- `libs/frontman-nextjs/src/FrontmanNextjs__ToolRegistry.res`
- `libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__Templates.res`
- `libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__AutoEdit.res`
- `libs/frontman-nextjs/src/FrontmanNextjs__SpanProcessor.res`
- `test/sites/blog-starter/src/proxy.ts`

The Next.js registry combines core tools with route/log tools and framework-specific edit behavior. Generated middleware matchers and installer edits must explicitly route `/mcp`; replacing only the shared core handler would leave existing generated integration configurations unable to reach the endpoint.

The span processor currently suppresses only `/frontman` traffic. It must also suppress `/mcp` so protocol requests do not pollute application logs or expose request metadata through log tools.

Affected tests:

- `libs/frontman-nextjs/test/FrontmanNextjs__Middleware.test.res`
- `libs/frontman-nextjs/test/FrontmanNextjs__ToolRegistry.test.res`
- `libs/frontman-nextjs/test/cli/FrontmanNextjs__Cli__AutoEdit.test.res`
- `libs/frontman-nextjs/test/cli/FrontmanNextjs__Cli__Install.test.res`
- `libs/frontman-nextjs/test/FrontmanNextjs__SpanProcessor.test.res`
- `test/e2e/tests/nextjs.test.ts`

#### Astro

Relevant files:

- `libs/frontman-astro/src/FrontmanAstro__Middleware.res`
- `libs/frontman-astro/src/FrontmanAstro__Server.res`
- `libs/frontman-astro/src/FrontmanAstro__ToolRegistry.res`
- `libs/frontman-astro/src/FrontmanAstro__Integration.res`
- `libs/frontman-astro/src/FrontmanAstro__ViteAdapter.res`
- `libs/frontman-astro/src/astro-route-rewrite.mjs`

The Astro registry combines core tools with page, route, log, content-collection, and framework-specific edit tools. `/mcp` must run before Astro page routing and must be excluded from trailing-slash or Frontman UI route rewriting. Node request close/abort must propagate into Web API stream cancellation.

Affected tests:

- `libs/frontman-astro/test/FrontmanAstro__Tool__GetContentCollections.test.res`
- `libs/frontman-astro/test/FrontmanAstro__Tool__GetLogs.test.res`
- `libs/frontman-astro/test/FrontmanAstro__Tool__GetResolvedRoutes.test.res`
- `libs/frontman-astro/test/astro-route-rewrite.test.mjs`
- `libs/frontman-astro/test/FrontmanAstro__Integration.test.res`
- `test/e2e/tests/astro.test.ts`
- `test/astro-compat/fixture/tests/dev-server.test.mjs`

#### Vite

Relevant files:

- `libs/frontman-vite/src/FrontmanVite__Middleware.res`
- `libs/frontman-vite/src/FrontmanVite__Server.res`
- `libs/frontman-vite/src/FrontmanVite__Plugin.res`
- `libs/frontman-vite/src/FrontmanVite__ToolRegistry.res`
- `libs/frontman-vite/src/FrontmanVite__Bindings.res`

The Vite registry combines core tools with Vite logs and edit behavior. The plugin's early route guard must recognize `/mcp`. The Node-to-Web request bridge currently needs explicit aborted/close event bindings so Streamable HTTP cancellation reaches tool execution.

Affected tests:

- Create transport, middleware, cancellation, and tool-registry tests under `libs/frontman-vite/test/`; this directory does not currently exist.
- `test/e2e/tests/vite.test.ts`
- `test/e2e/tests/vue-vite.test.ts`

#### Shared framework behavior

`libs/frontman-core/src/FrontmanCore__ToolRegistry.res:36-47` replaces framework-specific tools by name inside one registry, which is explicit. Browser-local versus framework tool collisions are not explicit and currently resolve local-first.

All framework adapters need one shared black-box protocol suite so status codes, headers, errors, discovery, listing, execution, cancellation, and Origin behavior cannot drift by adapter.

Vite and Astro currently duplicate the Node Connect-to-Web Request/Response bridge. Before adding cancellation, consolidate body collection, raw-byte response streaming, request abort, response close, and reader cancellation into sanctioned shared chassis using `libs/bindings/src/NodeHttp.res` and `frontman-core` where appropriate. Do not maintain two transport copies.

### WordPress Findings

WordPress independently implements the private relay rather than using `frontman-core`.

#### Router and security

`libs/frontman-wordpress/includes/class-frontman-router.php`:

- Lines 55-87 classify current prefix routes.
- Lines 60-66 require authentication and require a nonce for POST.
- Lines 315-332 return private relay discovery with version `1.0`.
- Lines 334-363 dispatch WordPress tools.
- Lines 365-380 always serialize tool outcomes as `event: result` SSE.

WordPress has materially stronger access control than the JavaScript framework relays. The `/mcp` migration must preserve authenticated session, capability checks, nonce validation, Playground scope handling, and private caching.

#### Tool registry and result shaping

`libs/frontman-wordpress/includes/class-frontman-tools.php`:

- Lines 25-101 define and serialize tools.
- Lines 103-148 manage registry and discovery.
- Lines 150-161 and 227-366 sanitize inputs.
- Lines 163-225 wrap canonical MCP-shaped results.

WordPress exposes post, block, media, menu, options, templates, widgets, cache, Elementor, and WooCommerce tools. It intentionally excludes filesystem/project-context tools; `libs/frontman-wordpress/tests/NoFilesystemToolsTest.php:65-98` enforces that policy.

#### WordPress migration concerns

- Route root and Playground-scoped `/mcp` before UI suffix handling.
- Replace private request bodies with complete JSON-RPC envelopes.
- Return JSON for synchronous operations instead of unconditional SSE.
- Validate required modern headers and body metadata.
- Preserve nonce handling on every MCP POST.
- Return exact HTTP and JSON-RPC error combinations.
- Use `cacheScope: private`.
- Validate Origin in addition to WordPress authentication.
- Keep tool visibility dependent on authorization context where appropriate.

#### WordPress tests affected

- `libs/frontman-wordpress/tests/RouterTest.php`
- `libs/frontman-wordpress/tests/NoFilesystemToolsTest.php`
- `libs/frontman-wordpress/tests/MediaToolsTest.php`
- `libs/frontman-wordpress/tests/ElementorToolsTest.php`
- `libs/frontman-wordpress/tests/WooCommerceToolsTest.php`
- `libs/frontman-wordpress/tests/MutationSnapshotsTest.php`
- `libs/frontman-wordpress/tests/integration/WordPressRuntimeTest.php`
- `.github/workflows/wordpress-compatibility.yml`

#### WordPress prerequisite verification status

The standalone comment-removal implementation updates authored PHP and WordPress package source without changing the private relay or implementing `/mcp` behavior.

Verified on `2026-08-07`:

- `make package-wordpress-plugin VERSION=2.0.0` succeeded.
- The build produced the plugin ZIP, WordPress.org tarball, and expanded WordPress.org package under ignored `dist/` output.
- The repository-wide source-aware comment scan passes for tracked WordPress PHP, assets, tests, and packaging source.
- The approved leading metadata header in `libs/frontman-wordpress/frontman.php` is preserved by an exact path- and field-aware scanner exception.
- WordPress protocol migration checklist items remain unchecked; the package still implements the existing private relay until its later atomic cutover.

Additional verification completed on `2026-08-07`:

- `make test-wordpress-core-tools` passed under PHP `8.4.24`, including filesystem-policy, Elementor, media, WooCommerce, mutation snapshot, plugin dependency, and router assertions.
- `make test-wordpress-runtime` passed against WordPress `7.0.2` and PHP `8.4.24` using Docker on OrbStack.
- The source scan, generated-schema diff check, and `git diff --check` passed after both WordPress targets.
- PHP `8.5` was not used as acceptance evidence because the router test invokes `ReflectionMethod::setAccessible()`, which PHP `8.5` deprecates; the supported runtime target and container both use PHP `8.4`.

## Existing Defects And Required Regression Tests

These rows preserve the pre-migration defect inventory. Completed Phase 1 items are recorded in the implementation status, package checklists, and implementation record; later-phase defects remain open until their required regression proof passes.

| Severity | Defect | Evidence | Required regression proof |
| --- | --- | --- | --- |
| High | Multiple task channels execute one tool call | `task_channel.ex:222-258`, `task_channel.ex:1001-1021`, `tasks.ex:249-264` | Two channels, tabs, and claim contenders produce one owned invocation |
| High | Framework file tools are exposed cross-origin | `FrontmanCore__CORS.res:4-8`, `FrontmanCore__Middleware.res:164-180`, `FrontmanCore__ToolRegistry.res:16-28` | Hostile Origin receives 403 and no tool side effect |
| High | Empty valid content does not notify live executor | `execution.ex:142-154` | `content: []` completes the exact waiting request once |
| High | Empty and modern content fail historical reconstruction | `interaction.ex:1133-1174` | Empty and every official content block replay safely into model history |
| High | Modern result fields are stripped during persistence | `interaction.ex:920-935` | `resultType` and the canonical validated result survive persistence and replay |
| High | Audio and resource content can crash delivery | `execution.ex:156-164`, `execution.ex:241-244`, `tool_executor.ex:193-207`, `interaction.ex:1170-1174` | Every official content block persists and converts without exceptions through every live and historical path |
| High | Relay failure is called nonfatal but blocks new sessions | `Client__ConnectionReducer.res:182-199`, `273-277`, `307-318`, `390` | Explicit browser-only policy is tested for create and load flows |
| High | Adapter changes do not trigger E2E CI | `.github/workflows/e2e.yml:5-15` | Every MCP core, protocol, adapter, fixture, and root verification change triggers its owning E2E suite |
| Medium | Initialization can block prompts forever | `mcp_initializer.ex:36-57`, `task_channel.ex:898-905` | Legacy initializer is removed; every modern request has bounded timeout |
| Medium | Version mismatch is ignored | `model_context_protocol.ex:27`, `FrontmanProtocol__MCP.res:4`, `mcp_initializer.ex:112-129` | Unsupported version returns exact `-32022` and never executes |
| Medium | Required nonstandard `callId` blocks interoperability | `FrontmanProtocol__MCP.res:37-43`, `FrontmanClient__MCP.res:128-139` | Standard `tools/call` works without `callId`; vendor metadata is optional/negotiated |
| Medium | Timed-out work continues and pending map grows | `tool_executor.ex:145-190`, `task_channel.ex:379-387`, `FrontmanClient__Relay.res:130-188` | Timeout aborts actual work, clears pending state, and ignores late result |
| Medium | Interactive reconnect overwrites old resolver | `Client__Tool__Question.res:53-79`, `Client__Task__Reducer.res:1185-1197` | Redispatch cannot leak or overwrite an unresolved promise |
| Medium | Malformed peer payloads can crash channel/state machine | `mcp_initializer.ex:112-140`, `mcp.ex:28-55` | Malformed discovery/list/tool entries produce deterministic protocol failure |
| Medium | Tool arguments are logged without redaction | `model_context_protocol.ex:115-122` | Sensitive fixture values never appear in captured normal logs |
| Medium | SSE parser rejects valid CRLF streams | `FrontmanClient__SSE.res:22-35`, `111-119` | LF, CRLF, comments, split delimiters, and split UTF-8 all pass |
| Medium | Malformed JSON can escape shared handler validation | `FrontmanCore__RequestHandlers.res:76-83`, `FrontmanCore__RequestHandlers.res:148` | Truncated, empty, invalid UTF-8, and invalid JSON return deterministic errors on every endpoint, never 500 |
| Low | SSE error results are double-wrapped | `FrontmanCore__SSE.res:26-32`, `FrontmanClient__SSE.res:62`, `FrontmanClient__MCP__Server.res:223-234` | End-to-end execution error preserves original typed result once |
| Low | Tool-name collisions silently hide relay tools | `FrontmanClient__MCP__Server.res:186-238` | Catalog collision is rejected or deterministically namespaced |
| Low | Attachment rewriting depends on hard-coded names | `FrontmanClient__MCP__Server.res:202-220` | Attachment capability is schema/extension-driven or explicitly scoped and tested |

## Current Protocol Data Flow And Ownership Analysis

The flows below preserve the pre-cutover baseline used to derive the target ownership model. The Phase 1 consumer-cutover delta is recorded in the implementation record and package checklists.

### Current connection and discovery flow

```text
1. Client provider creates browser tool registry and private HTTP relay.
2. Browser GETs /frontman/tools and stores relay tools in mutable relay state.
3. ACP creates or joins task:{task_id} Phoenix channel.
4. Browser attaches MCP handler before channel join.
5. Phoenix TaskChannel joins and creates connection-scoped MCP initializer state.
6. Phoenix sends initialize.
7. Browser ignores requested version and returns its own version/capabilities.
8. Phoenix sends notifications/initialized.
9. Phoenix sends tools/list.
10. Browser combines local and relay tools, local-first, and returns one page.
11. Phoenix optionally calls load_agent_instructions and list_tree.
12. Phoenix marks that task channel MCP-ready and wakes queued agent work.
```

Ownership consequences:

- MCP lifecycle is bound to one ACP task channel.
- Every opened task channel repeats discovery and project-context loading.
- Capability/version identity is inferred from prior messages on that channel.
- Tool context is inferred from the ACP session ID stored in the handler.
- A missing response can hold queued prompts indefinitely.

### Current tool-call flow

```text
1. LLM emits a tool call with durable tool_call_id.
2. ToolExecutor registers itself in node-local ToolCallRegistry.
3. Tasks persists ToolCall and broadcasts the interaction to task:{task_id}.
4. Every joined TaskChannel receives the ToolCall.
5. Every receiving TaskChannel classifies it as MCP and creates a fresh integer request ID.
6. Each channel stores request_id => durable tool_call_id.
7. Each channel pushes tools/call with nonstandard params.callId.
8. Each browser handler checks local tools first, then relay tools.
9. Relay execution POSTs a private body and waits for custom SSE.
10. Browser returns a JSON-RPC response to its TaskChannel.
11. TaskChannel maps request ID back to durable tool_call_id.
12. Tasks persists ToolResult; database uniqueness rejects later duplicates.
13. Execution.notify_tool_result converts content and notifies the waiting executor.
14. TaskChannel pushes an ACP tool update and may resume the agent.
```

Ownership consequences:

- Persistence owns the durable tool call, but no component exclusively owns execution.
- TaskChannel owns transient correlation, so disconnect destroys request knowledge.
- Registry owns live waiter delivery only on one node.
- Browser and framework have no cancellation owner.
- Database uniqueness guarantees one stored result, not one external side effect.

### Current reconnect flow

```text
1. Browser disconnect leaves unresolved ToolCall persisted.
2. A new task channel joins and repeats legacy initialization.
3. session/load marks the new channel ready for recovery.
4. After MCP readiness, the channel queries unresolved active-run tool calls.
5. It redispatches each unresolved call with a fresh JSON-RPC ID and original callId.
6. For question, a new browser promise and resolver replace current pending UI state.
7. First stored ToolResult wins; duplicate side effects remain possible.
```

Ownership consequences:

- Recovery is a blind replay rather than lease transfer.
- The original browser execution may still be running.
- Interactive resolver callbacks can leak.
- Non-idempotent writes may execute again.

### Target ownership flow

```text
1. Browser attaches one MCP handler to the existing authenticated connection-wide `tasks` channel.
2. The existing Phoenix `TasksChannel` process owns discovery, catalog state, request IDs, and pending state for that browser connection.
3. ToolExecutor requests execution through that connection owner with task and durable tool-call context.
4. The connection owner atomically claims the durable tool call for its MCP connection.
5. The connection owner sends one stateless tools/call request with full _meta.
6. Browser deduplicates the durable Frontman tool-call identifier.
7. Browser executes local tool or standard Streamable HTTP call.
8. Cancellation propagates through the connection owner, browser AbortController, HTTP stream, and tool context.
9. The connection owner validates the response by pending request kind before persistence.
10. Tasks persists one canonical result and completes the claim transactionally.
11. All task channels observe persisted interactions and publish UI updates only.
12. Reconnect requires explicit claim transfer or lease expiry before replay.
```

Target ownership assignments:

| Concern | Owner |
| --- | --- |
| MCP server connection | Browser MCP server instance and existing Phoenix `TasksChannel` connection process |
| Protocol discovery/cache | Existing Phoenix `TasksChannel` connection process |
| HTTP framework discovery/cache | Browser Streamable HTTP MCP client |
| JSON-RPC wire correlation | Issuing MCP client transport |
| Durable agent tool identity | Tasks persistence |
| Exclusive execution claim | Atomic durable claim state on the existing interaction row where correct; separate claim record only if lease semantics require it |
| Live agent waiter | Tool executor with connection-owner-mediated completion |
| Browser-local cancellation | Browser MCP handler AbortController |
| Framework cancellation | Streamable HTTP response stream and tool context signal |
| UI observation | Task channels through persisted interaction broadcasts |

## Package-Specific Migration Checklists

### `libs/frontman-protocol`

- [x] Pin official schema, examples, license, provenance, and checksums.
- [x] Add offline JSON Schema 2020-12 oracle and official-example conformance tests.
- [x] Replace `FrontmanProtocol__MCP.res` in place with the modern latest-only contract; consumers and schemas are cut over, the version is `2026-07-28`, and no `MCP20260728` parallel API remains.
- [x] Consolidate modern content variants into `FrontmanProtocol__ContentBlock.res` and add lossless generic request/notification/result/error response and exclusive message schemas in `FrontmanProtocol__JsonRpc.res`; public consumers are cut over.
- [x] Generalize JSON-RPC IDs without 32-bit narrowing.
- [x] Add bounded generic, request, result, and notification metadata contracts with reserved-field validation and lossless vendor metadata preservation.
- [x] Add exact implementation identity with shared icon reuse, open client/server capability contracts, and namespaced extension maps.
- [x] Add exact cancellation notification and notification metadata wire contracts.
- [x] Add the exact accepted Streamable HTTP SSE message domain.
- [x] Add modern errors required by the initial implementation.
- [x] Add exact discovery, cache-hint, Tool, `tools/list`, and `tools/call` request wire contracts.
- [x] Add lossless `InputResponses` and all three nested InputRequest variant contracts without advertising optional capabilities or adding fulfillment machinery.
- [x] Assemble the exact `InputRequests` union and add `InputRequiredResult` recognition without automatic MRTR fulfillment or retry.
- [x] Keep shared wire recognition free of production MRTR, progress, emitted SSE, server pagination, and subscription machinery until a caller exists.
- [x] Support all content blocks and arbitrary JSON structured content in the shared ReScript wire contract; persistence, Elixir, ACP history, model conversion, and end-to-end support remain Phase 9 work.
- [x] Define only the minimal Frontman extension needed for explicit task context and durable tool-call identity.
- [ ] Remove private Relay protocol types after client/server cutover.
- [x] Replace generated schemas atomically and remove legacy/version-parallel MCP schema exports.
- [x] Differentially validate locally accepted Phase 1 domains against upstream definitions with deterministic generated cases, focused exhaustive vectors, and explicit authoritative-artifact discrepancy tests.
- [x] Add a breaking changeset.

### `libs/frontman-client`

- [x] Remove initialize-era browser dispatcher behavior.
- [x] Implement `server/discover` on the custom Phoenix dispatcher.
- [x] Validate `_meta` on every supported custom Phoenix request.
- [x] Implement modern list/call/result/error behavior on the custom Phoenix dispatcher.
- [ ] Add cancellation and in-flight request tracking; structural notification validation exists, but correlation, actual abort, and late-response suppression remain.
- [x] Remove silent `Suspended` response loss.
- [x] Stop deriving task context from the channel session ID; require explicit execution-context metadata.
- [ ] Replace Relay with Streamable HTTP MCP client.
- [ ] Implement required standard and `x-mcp-header` headers.
- [ ] Implement JSON and standards-compliant SSE response parsing.
- [ ] Fetch all remote list pages defensively, detect repeated cursors, and cache only where the remote server supplies valid caching metadata.
- [ ] Add abort propagation and late-response suppression.
- [ ] Reject or namespace tool collisions.
- [ ] Own listener registration by callback reference so ACP/task cleanup cannot remove the connection-wide MCP handler.
- [ ] Expand concurrency and custom-transport tests.
- [ ] Remove private relay generated artifacts and tests.
- [x] Add a breaking changeset for the custom Phoenix contract cutover; Streamable HTTP changes remain later work.

### `libs/client`

- [x] Supply explicit browser MCP server identity and execution-context extension metadata.
- [ ] Remove relay-state assumptions from session lifecycle.
- [ ] Define and test browser-only behavior when framework MCP is unavailable.
- [ ] Keep Streamable HTTP transport, parsing, cache, correlation, and cancellation in `frontman-client`; use the existing `Client__ConnectionReducer` only to orchestrate lifecycle and expose state.
- [ ] Make question execution cancellable and reconnect-safe.
- [ ] Decide later whether to advertise Elicitation.
- [ ] Preserve attachment resolution through documented metadata rather than hidden name conventions.
- [ ] Preserve provider lifecycle, update-banner server information, and WordPress Playground-scoped endpoint construction.
- [x] Update tool registry serialization and policy tests for the custom-Phoenix cutover; framework Streamable HTTP serialization remains later work.
- [ ] Update task recovery tests.
- [ ] Add a breaking changeset.

### `libs/frontman-core`

- [ ] Replace private request handlers with one `POST /mcp` dispatcher.
- [ ] Implement discovery, listing, calling, and exact errors.
- [ ] Implement header/body validation and Base64 sentinel decoding.
- [ ] Implement JSON response negotiation.
- [ ] Return synchronous JSON initially; retain only standards-compliant response plumbing needed to add emitted SSE when a real progress or streaming producer exists.
- [ ] Propagate stream cancellation into tool execution.
- [ ] Add strict Origin policy and remove wildcard MCP CORS.
- [ ] Define and test a non-MCP Origin/CORS policy for `/frontman/resolve-source-location`.
- [ ] Serialize standard tools with deterministic order.
- [ ] Map read behavior to standard annotations, filter hidden tools before serialization, and keep execution timing policy internal.
- [ ] Reuse Sury tool schemas and `FrontmanCore__Server.executeTool`; add generic runtime schema validation only at untyped remote boundaries.
- [ ] Correct unknown-tool versus tool-execution error classification.
- [ ] Remove relay routes, protocol version, and private SSE helpers.
- [ ] Add complete black-box transport and security tests.
- [ ] Add a breaking changeset.

### `libs/frontman-nextjs`

- [ ] Route `/mcp` through middleware and generated matchers.
- [ ] Update installer and automatic-edit templates.
- [ ] Update checked-in site fixtures and suppress `/mcp` in the span processor.
- [ ] Remove old server wrapper methods.
- [ ] Propagate request close to cancellation where adapter APIs permit.
- [ ] Run shared MCP black-box suite.
- [ ] Update Next.js E2E tests.
- [ ] Update documentation and changeset.

### `libs/frontman-astro`

- [ ] Route `/mcp` before Astro application routing.
- [ ] Exclude `/mcp` from UI rewrites and trailing-slash normalization.
- [ ] Use the consolidated shared Node/Web chassis for request abort, response close, and raw-byte streaming.
- [ ] Remove old server wrapper methods.
- [ ] Run shared MCP black-box suite.
- [ ] Update Astro and Astro-compatibility E2E tests.
- [ ] Update documentation and changeset.

### `libs/frontman-vite`

- [ ] Add `/mcp` to the early plugin route guard.
- [ ] Consolidate the duplicated Vite/Astro Node/Web bridge into shared chassis before adding abort/close bindings.
- [ ] Propagate cancellation to Web streams and tools through that one shared bridge.
- [ ] Remove old server wrapper methods.
- [ ] Create package transport/middleware tests and run the shared MCP black-box suite.
- [ ] Update Vite and Vue-Vite E2E tests.
- [ ] Update documentation and changeset.

### `libs/frontman-wordpress`

- [ ] Add modern root and scoped `/mcp` route classification.
- [ ] Implement JSON-RPC request validation and dispatch.
- [ ] Preserve session authentication, capability checks, and nonce validation.
- [ ] Add exact Origin validation.
- [ ] Implement discovery, listing, calling, and modern error envelopes.
- [ ] Return JSON for synchronous operations.
- [ ] Use private cache scope.
- [ ] Preserve no-filesystem-tools policy.
- [ ] Remove old relay routes and unconditional custom SSE.
- [ ] Run shared black-box vectors plus WordPress-specific auth vectors.
- [ ] Update runtime, compatibility workflow, docs, and changeset.

### `libs/frontman-astro-browser`

- [ ] Update tool result constructors to include modern result fields.
- [ ] Validate Astro audit tool schemas and standard metadata.
- [ ] Update registry and result tests.
- [ ] Add changeset if published behavior changes.

### `apps/frontman_server`

- [x] Replace `DRAFT-2025-v3` with latest-only `2026-07-28` request metadata.
- [ ] Remove MCP initializer module and tests.
- [ ] Move connection-wide MCP ownership into the existing authenticated `TasksChannel`; do not add a broker process or second connection channel.
- [x] Implement discovery and the minimal catalog state in the temporary TaskChannel owner; connection-wide ownership remains Phase 5 work.
- [ ] Move project-context loading outside protocol initialization.
- [ ] Remove MCP routing from task interaction observers.
- [ ] Add atomic durable execution claim state using the existing interaction row where correct; add a claim table and migration only if required for sound lease semantics.
- [ ] Implement bounded request timers, cancellation, claim release, and minimal late-response rejection; defer progress and MRTR until they have callers.
- [x] Validate every browser response against its pending method schema on the temporary custom-Phoenix path.
- [ ] Persist one canonical validated modern result and use it for live delivery, historical reconstruction, ACP presentation, and model conversion; Phase 1 preserves complete result fields and scrubs `_meta`, while complete content conversion remains Phase 9 work.
- [ ] Support empty content and every content block without raising Base64 or function-clause failures.
- [ ] Validate arbitrary structured content and output schemas.
- [ ] Remove tool arguments and malformed argument payloads from every logging path.
- [ ] Replace local-only ownership assumptions for clustered execution.
- [ ] Update recovery and resume behavior.
- [x] Replace Phase 1 legacy contract tests with generated-schema, pinned-upstream, and shared ReScript/Elixir parity evidence; broader transport compliance remains later work.
- [ ] Add multi-channel, multi-owner, cancellation, timeout, and late-response tests.

### Root, E2E, CI, And Documentation

- [x] Add one package-local MCP verification target and one root aggregate target; add more only for distinct runtime setup.
- [ ] Add shared adapter black-box fixtures.
- [ ] Add official conformance-runner gate pinned offline.
- [x] Add deterministic property tests with `1,000` pull-request cases and a checksum-pinned `10,000`-case scheduled/manual workflow.
- [ ] Add multi-node and fault-injection scheduled tests.
- [ ] Update Next.js, Astro, Vite, Vue-Vite, WordPress, and Playground E2E tests.
- [ ] Correct E2E workflow path filters so every protocol, core, adapter, fixture, generated asset, and root MCP verification change runs its owner.
- [ ] Add custom Phoenix transport documentation.
- [x] Add Frontman MCP extension documentation.
- [x] Add Phase 0 implementation limits, normative traceability matrices, and threat model.
- [ ] Add the release capability matrix and replace planned traceability locations with final code and test evidence.
- [ ] Update `README.md`, architecture docs, integration docs, and marketing language.
- [x] Remove obsolete `docs/mcp_schema.ts` or replace it with an explicit pointer to pinned upstream artifacts.
- [ ] Add migration documentation for the breaking latest-only release.
- [x] Remove or regenerate Phoenix browser-test bundles and every other shipped artifact containing legacy protocol behavior.
- [x] Enforce zero comments, docblocks, suppressions, TODO/FIXME markers, and commented-out code across tracked authored source, allowing only approved platform-required executable directives. The prerequisite is merged and its repository, packaging, WordPress core-tool, and WordPress runtime proof gate is accepted.

## Target Architecture

```text
Phoenix MCP client
    |
    | MCP 2026-07-28 JSON-RPC
    | documented custom Phoenix transport
    v
Browser MCP server and Streamable HTTP MCP client
    |
    | MCP 2026-07-28 Streamable HTTP
    | POST /mcp
    v
Next.js / Astro / Vite / WordPress MCP servers
```

### Role Boundaries

Phoenix remains the MCP client on the custom browser transport.

The browser remains the MCP server for browser-local tools and becomes a standard MCP client for framework tools.

Each framework integration becomes a standard MCP Streamable HTTP server.

ACP remains the application protocol between the UI and the agent orchestrator. ACP task/session concepts must not leak into MCP as implicit connection state.

## Non-Negotiable Design Rules

1. The final implementation supports only protocol version `2026-07-28`.
2. Every MCP request is self-describing and independently validated.
3. No MCP server infers task, user, capability, version, or authorization context from connection history.
4. Every successful result contains `resultType`.
5. Every advertised capability has complete implementation and tests.
6. Unsupported optional features are not advertised or approximated.
7. Frontman-specific data uses documented, negotiated, reverse-DNS-prefixed extensions.
8. All tool schemas use JSON Schema 2020-12 unless explicitly declaring another supported dialect.
9. External `$ref` values are never fetched automatically.
10. Parsing failures, malformed peer data, unsupported content, and cancellation never crash an executor or channel.
11. One durable tool call can cause at most one owned external execution at a time.
12. No test relies on network access to fetch the standard, schema, examples, or conformance runner.
13. Existing shared owners are updated in place; no parallel MCP contract, broker process, adapter bridge, or compatibility fallback survives the migration.
14. Tracked authored repository source contains no comments, docblocks, suppressions, TODO/FIXME markers, or commented-out code other than approved platform-required executable directives; generated artifacts and build outputs are excluded from this rule.

## Prerequisite: Repository-Wide Comment Removal

Complete tracked-authored-source comment removal before protocol implementation so the migration does not mix recurring comment cleanup with behavioral changes.

Search every tracked authored source file, including authored files under `apps/`, `libs/`, `test/`, `scripts/`, `.github/`, installer templates, and fixtures. Remove source comments, documentation comments, lint and type suppression directives, TODO/FIXME notes, and commented-out code. Preserve only approved platform-required executable directives. Exclude generated artifacts and build outputs from comment cleanup and enforcement.

Add one repository-wide source-aware verification command that fails on prohibited comments in tracked authored source and runs in local precommit and CI. The scanner must distinguish source comments from strings, regular expressions, standalone prose, licenses, protocol examples, immutable data, generated artifacts, and build outputs by file type and ownership; do not maintain broad exclusions that can hide authored source.

### Implementation Record

Status: merged and accepted.

- [x] Remove lexical source comments, documentation comments, Elixir documentation attributes, TODO/FIXME notes, and commented-out code from tracked authored source.
- [x] Preserve interpreter shebangs, the exact leading WordPress plugin metadata header, and valid TypeScript triple-slash reference directives.
- [x] Preserve standalone prose, licenses, protocol JSON, immutable fixture data, strings, regular expressions, SVG CDATA, and generated build output.
- [x] Add `scripts/no-comments.mjs` with tracked-file enumeration and exact generated-artifact exclusions.
- [x] Cover ReScript and C-like source, Elixir and HEEx, PHP, HTML/Astro/Vue/SVG/XML, CSS, shell and typed heredocs, Python and docstrings, YAML/TOML/INI/service files, SQL, batch files, Dockerfiles, Makefiles, Caddyfiles, environment files, and executable shebang files.
- [x] Add scanner fixtures and regression tests for directives, regex and string markers, template interpolation, generated installer source, WordPress metadata, SVG CDATA, Elixir docblocks, Python docstrings, Node/Python/SQL/shell heredocs, safe autofix, tracked-file ownership, and exact generated exclusions.
- [x] Make autofix preserve bytes outside detected source comments and preserve syntactically valid Python blocks with `pass` when a removed docstring was the block body.
- [x] Add root `make check-source-comments`.
- [x] Run the check from root Lefthook precommit and an unconditional CI job.
- [x] Preserve Makefile help output without comment-powered parsing.
- [x] Align Credo configuration and commands so the repository policy does not conflict with `Credo.Check.Readability.ModuleDoc`.
- [x] Run the repository source scan, scanner tests, diff checks, shell syntax checks, ReScript build, protocol schema regeneration check, Elixir precommit suites, JavaScript/ReScript package suites, marketing build, Astro package verification, and WordPress packaging.
- [x] Run `make test-wordpress-core-tools` with PHP available.
- [x] Run `make test-wordpress-runtime` with Docker available.
- [x] Rerun the source scan and generated-diff checks after WordPress tests.
- [x] Accept the prerequisite proof gate.
- [x] Commit and merge the standalone change before protocol implementation.

Verification recorded on `2026-08-07`:

- Scanner unit tests: `21` passed.
- Repository source scan: passed with zero reported prohibited comments.
- Root ReScript build: passed.
- `apps/swarm_ai`: warnings-as-errors compile, formatting, Credo, and `112` tests passed.
- `apps/frontman_notifier`: warnings-as-errors compile, formatting, Credo, and `3` tests passed.
- `apps/frontman_server`: warnings-as-errors compile, formatting, Credo, and `727` tests passed.
- `libs/client`: `319` tests passed.
- `libs/frontman-client`: `69` tests passed.
- `libs/frontman-core`: `321` tests passed when rerun serially; an earlier parallel run was invalid because another ReScript clean removed generated modules during Vitest startup.
- `libs/frontman-nextjs`: `182` tests passed.
- `libs/frontman-astro`: `59` tests passed.
- `libs/frontman-astro-browser`: `4` tests passed.
- `libs/logs`: `11` tests passed.
- `libs/react-statestore`: `4` tests passed.
- `apps/marketing`: `28` tests and the production build passed with no diagnostics or broken links.
- `libs/frontman-protocol`: schema export and generated-diff check passed.
- `test/astro-compat`: package verification passed.
- WordPress packaging for version `2.0.0`: passed.
- Changed shell files: `bash -n` passed.
- `git diff --check`: passed.
- Root and package Makefile help targets: passed.
- No standalone license-verification Make target exists; standalone license and prose files are excluded from source-comment cleanup and remain unchanged.
- `libs/frontman-vite`: ReScript build passed, but its existing test target reports no test files; the plan already requires creation of the package test suite during adapter migration.
- WordPress core-tool tests: passed under PHP `8.4.24`.
- WordPress runtime tests: passed against WordPress `7.0.2` and PHP `8.4.24` using Docker on OrbStack.

### Proof Gate

- [x] The repository-wide source-aware comment scan passes on tracked authored source files.
- [x] Existing build, test, license, and packaging checks pass after the standalone cleanup. All defined checks pass; no standalone license-verification target exists.
- [x] The cleanup contains no protocol or behavioral changes. MCP behavior remains unchanged; Makefile help and lint behavior were adjusted only to preserve existing developer workflows under the source-comment policy.

Current proof-gate result: accepted and merged. The source scan, builds, tests, packaging, WordPress core-tool and runtime tests, and generated checks pass. The Vite package has no current test files and remains covered only by build verification until its explicitly planned adapter suite is created.

## Phase 0: Normative Oracle And Traceability

### Work

Pin the authoritative TypeScript schema and generated `2026-07-28` JSON Schema at the same immutable upstream commit. Treat the TypeScript schema as the source of truth and the JSON Schema as validation tooling. Record the TypeScript schema's immutable URL and checksum without vendoring its commented source; vendor the generated JSON Schema unchanged.

Record both upstream artifacts and vendor the generated JSON Schema unchanged with:

- Upstream repository and commit.
- Original source path and immutable URL.
- SHA-256 checksum.
- Upstream license.
- A statement that local modifications are absent.

Pin official examples and the official conformance runner or a checksum-pinned source archive.

Create a normative traceability matrix with these columns:

| Requirement ID | Normative text | Applicability | Code location | Positive test | Negative test | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |

Record every applicable `MUST`, `MUST NOT`, `REQUIRED`, `SHOULD`, and `SHOULD NOT` from:

- Base protocol.
- Versioning.
- Custom transport rules.
- Streamable HTTP.
- Discovery.
- Tools.
- Caching.
- Pagination.
- MRTR, recorded as not implemented unless a later separately approved feature changes applicability.
- Cancellation.
- Progress if implemented.
- Authorization and security.
- Extension negotiation.

Define explicit implementation limits:

- Maximum HTTP body bytes.
- Maximum JSON nesting depth.
- Maximum metadata bytes and keys.
- Maximum tool count and definition bytes.
- Maximum pagination pages and repeated-cursor protection.
- Maximum schema depth, subschemas, and validation duration.
- Maximum result content blocks and decoded media bytes.
- Request idle and absolute timeout policies.
- Maximum bounded late-response tracking retained by the chosen minimal correlation design.
- Ownership lease duration.

### Proof Gate

- Vendored artifacts pass checksum verification offline.
- The schema is loaded with a JSON Schema 2020-12 validator.
- Official examples validate against their named upstream definitions.
- The traceability matrix contains every applicable normative requirement.
- Limits have concrete values, measurement and rejection behavior, owners, and exact at-boundary and immediately-over-boundary test vectors. Each owning implementation phase must pass its vectors before acceptance; Phase 0 must not add parallel placeholder runtime owners merely to execute future tests.

### Acceptance Record

- [x] Vendored schema, examples, license, and conformance archive checksums verify offline.
- [x] The unchanged generated schema loads with Ajv's JSON Schema 2020-12 validator.
- [x] All `129` official examples validate against the upstream definition named by their directory.
- [x] The four traceability matrices structurally verify `443` unique requirement IDs with the required evidence columns.
- [x] Initial applicability decisions include explicit non-applicable and deprecated features, core `input_required` recognition without automatic MRTR machinery, latest-only version handling, and no OAuth conformance claim for existing WordPress authentication.
- [x] Every implementation limit has a concrete inclusive maximum, measurement rule, rejection behavior, owner, and exact at-limit and immediately-over-limit proof vector.
- [x] The threat model records assets, trust boundaries, mitigations, current evidence, planned release evidence, and residual risks.
- [x] Root and package `mcp-verify` targets and CI run the offline oracle and traceability gates.

### Implementation Evidence

- Specification release commit: `5f5440bb26a62e2cf3440b92da5a667efa03b267`.
- Authoritative TypeScript schema SHA-256: `742750af0bb8c716e7030c4977c992b55d1adc4407e9e66997db5846baedc2cd`; its immutable URL is recorded without vendoring the commented source.
- Vendored generated JSON Schema SHA-256: `ef70b61f99b6d2e5e3b46863822eab08dff6a45bedc7a08914e0e5b133f40203`.
- Conformance source commit: `c321dd32035556e6769d3724a8ee97d87c3faaac`; vendored archive SHA-256: `57ecc92fc89d9a51139713a7ea92e1376929b2a1bcae2b735b4c303e15ed23d9`.
- Provenance, checksums, unchanged schema, official examples, license, and conformance archive: `libs/frontman-protocol/test/mcp-upstream/`.
- Offline oracle verifier: `libs/frontman-protocol/scripts/VerifyMcpOracle.mjs` using Ajv's JSON Schema 2020-12 implementation and `ajv-formats`.
- Oracle regression tests: `libs/frontman-protocol/test/VerifyMcpOracle.test.mjs`, covering changed, omitted, and duplicate manifest artifacts plus an upstream-definition negative case.
- Traceability index and matrices: `docs/mcp/traceability.md` and `docs/mcp/traceability/`.
- Traceability structural verifier and tests: `libs/frontman-protocol/scripts/VerifyMcpTraceability.mjs` and `libs/frontman-protocol/test/VerifyMcpTraceability.test.mjs`.
- Frozen decisions, limits, and threat model: `docs/mcp/phase-0-decisions.md`, `docs/mcp/implementation-limits.md`, and `docs/mcp/threat-model.md`.
- Public verification commands: `make -C libs/frontman-protocol mcp-verify` and root `make mcp-verify`.
- CI ownership: `.github/workflows/ci.yml` runs the oracle, traceability, and generated-schema checks for protocol, MCP documentation, and root Makefile changes.
- Verification result on `2026-08-08`: six verifier tests passed, all `129` official examples validated, all `443` traceability requirement IDs verified, generated schemas were current, the repository source-comment gate passed, Make help exposed both verification targets, and `git diff --check` passed.

Phase 0 accepted on `2026-08-08`. Runtime rows remain `Planned` until their owning phases replace planned locations with implementation and positive/negative test evidence.

## Phase 1: Shared MCP Wire Contract

### Work

Replace the existing initialization-era `FrontmanProtocol__MCP.res` contract in place and consolidate common values into the existing `FrontmanProtocol__JsonRpc.res` and `FrontmanProtocol__ContentBlock.res` modules. Delete any parallel `MCP20260728` runtime export and its duplicate generated schemas before completing this phase.

Implement exact modern wire contracts required by Frontman's initial methods for:

- JSON-RPC request IDs as string or integral number.
- Request metadata.
- Result metadata.
- Implementations and icons.
- Client and server capabilities.
- Namespaced extensions.
- Cache scope.
- `server/discover` request and result.
- Standard Tool definitions.
- `tools/list` request and result.
- `tools/call` request.
- Complete tool result.
- Input response/request maps and input-required results needed for exact tools-call interoperability.
- Cancellation notification parameters and notification metadata.
- Generic lossless notification, result-response, and error-response envelopes.
- The decoded Streamable HTTP SSE message domain.
- Standard content blocks.
- Modern protocol errors.

Every request must include:

```json
{
  "_meta": {
    "io.modelcontextprotocol/protocolVersion": "2026-07-28",
    "io.modelcontextprotocol/clientCapabilities": {},
    "io.modelcontextprotocol/clientInfo": {
      "name": "frontman",
      "version": "<application-version>"
    }
  }
}
```

Every normal result must include:

```json
{
  "resultType": "complete"
}
```

Complete tool results support:

- Text content.
- Image content.
- Audio content.
- Resource links.
- Embedded text resources.
- Embedded blob resources.
- Arbitrary JSON `structuredContent`, including object, array, string, number, boolean, and null.

Remove from the core MCP schema:

- `initializeParams`.
- `initializeResult`.
- `callId`.
- `Suspended` without a response.
- Unnamespaced Frontman policy fields.

Represent only explicit task context and durable execution identity through one documented extension. This extension is mandatory for the custom Phoenix transport because safe execution ownership has no core-protocol fallback. A peer that does not negotiate it cannot execute a Frontman-owned browser tool call.

Advertise it under `capabilities.extensions`, provisionally:

```json
{
  "capabilities": {
    "extensions": {
      "ai.frontman/execution-context": {
        "version": 1
      }
    }
  }
}
```

Use vendor metadata such as:

```json
{
  "_meta": {
    "ai.frontman/execution-context": {
      "taskId": "...",
      "toolCallId": "..."
    }
  }
}
```

Map read behavior to standard annotations, filter hidden tools before serialization, and keep execution timing and interaction policy internal. Do not put `access`, `visibleToAgent`, or `executionMode` on the wire.

The exact extension shape and missing-extension error must be documented before implementation and tested for negotiation, preservation, and rejection of absent or malformed values. Do not implement a compatibility fallback.

### Proof Gate

- Every emitted wire fixture validates against the pinned official definition.
- Differential/property tests prove that values accepted by local schemas are accepted by upstream schemas, including ID, progress token, cancellation ID, icon theme, audience, resource size, tool input-schema root, and metadata boundaries.
- Required-field deletion tests fail validation.
- Wrong-type mutation tests fail validation.
- Arbitrary valid vendor metadata survives round-trip unchanged.
- Arbitrary JSON `structuredContent` survives round-trip unchanged.
- IDs preserve exact string or numeric type and value within the documented inclusive JavaScript safe-integer domain.
- ReScript and Elixir fixtures are structurally identical.

### Accepted Implementation Record

Status: review slices 1-5, the consumer cutover/evidence slice, deterministic differential generation, and final cleanup review are implemented; Phase 1 is accepted.

The review slices are checkpoints inside one atomic Phase 1 migration. They were not independently releasable states. Shared/custom-Phoenix consumers are cut over, initialization-era MCP schemas and duplicate modern artifacts are deleted, the shared protocol version is current, and the Phase 1 proof gate passes. The private HTTP relay is intentionally unchanged pending Phases 2-3, so Phase 1 acceptance is not complete-product release acceptance.

#### Review Slice 1: JSON-RPC Request IDs

Implemented in the existing `FrontmanProtocol__JsonRpc.res` owner:

- Replaced the internal numeric ID representation from ReScript `int` to JavaScript `float`, preserving exact numeric JSON IDs beyond the signed 32-bit range through both inclusive JavaScript safe-integer limits.
- Preserved string IDs as a distinct variant and retained exact string-versus-number wire type through parse and serialization.
- Changed generic request and response records, constructors, and accessors to use the shared abstract ID type rather than `int`.
- Added an explicit `fromInt` adapter for the existing ACP request counter and an optional `toInt` conversion at the ACP-only response-correlation boundary.
- Kept safe-integer parsing and serialization free of `Float.toInt`; the only narrowing operation is the explicit checked ACP compatibility conversion.
- Attached the local `string | safe integer` JSON Schema to the transformed Sury schema so generated request and response schemas expose the documented inclusive `-9,007,199,254,740,991` through `9,007,199,254,740,991` range rather than signed 32-bit limits or an unconstrained `{}` ID.
- Removed unused public `fromNumber` and `fromString` constructors after review; current callers either originate ACP integer IDs or parse peer IDs through the schema.
- Updated `FrontmanClient__ACP__Protocol.res`, `FrontmanClient__ACP__Client.res`, and existing JSON-RPC tests for the abstract ID boundary.

Evidence:

- `libs/frontman-protocol/test/VerifyMcpJsonRpcId.test.mjs` differentially checks locally accepted and rejected IDs against upstream `RequestId`.
- Accepted vectors include empty and non-empty string IDs, zero, negative one, `2,147,483,648`, and both JavaScript safe-integer limits.
- Rejected vectors include null, booleans, fractional numbers, objects, arrays, NaN, infinity, and the first positive and negative unsafe integers. Focused tests record that upstream's unrestricted integer schema accepts the two unsafe values while Frontman rejects them to prevent ID aliasing.
- Request and response envelope tests preserve string and wide numeric IDs exactly.
- Generated `schemas/jsonrpc/request.json`, `schemas/jsonrpc/response.json`, and every modern dependent schema expose string IDs or integers bounded to the documented JavaScript safe range.

#### Review Slice 2: Content Blocks And Complete Tool Results

Implemented in the existing `FrontmanProtocol__ContentBlock.res`, `FrontmanProtocol__MCP.res`, and `FrontmanProtocol__Tool.res` owners:

- Consolidated text, image, audio, resource-link, embedded-text-resource, and embedded-blob-resource values into the existing shared content module.
- Replaced the old annotation `_meta` placeholder with the official optional `audience`, `priority`, and `lastModified` fields.
- Restricted annotation audiences to `assistant` and `user` and priority to the inclusive `0.0` through `1.0` range.
- Added complete optional resource-link fields: title, description, MIME type, integral size, icons, annotations, and metadata.
- Restricted icon themes to `dark` and `light`.
- Represented resource size as an integral JavaScript number rather than ReScript `int`, avoiding another signed 32-bit narrowing defect.
- Added `_meta` to embedded text and blob resource contents and updated every current ReScript constructor with an explicit value.
- Required every content `_meta` value to be a JSON object.
- Added runtime URI validation for resource and icon locations while exporting the upstream `format: "uri"` schema.
- Added runtime standard-Base64 validation for image, audio, and blob data while exporting the upstream `format: "byte"` schema.
- Changed `CallToolResult.structuredContent` from an object dictionary to arbitrary `JSON.t`.
- Changed structured-result construction to preserve the original JSON value instead of narrowing through `JSON.Decode.object`.
- Required `resultType: "complete"` in the initial complete tool-result schema and every existing result constructor.
- Regenerated the MCP tool-result schema and every ACP schema that embeds the shared content schema.
- Updated browser MCP, ACP content, screenshot, attachment, annotation, and registry fixtures to use the modern result discriminator, embedded-resource metadata field, and valid Base64 data.

Evidence:

- `libs/frontman-protocol/test/VerifyMcpContentBlock.test.mjs` round-trips all official content variants and validates each against its named upstream definition.
- Negative vectors cover unknown audiences, priority above one, fractional resource size, unknown icon theme, non-object metadata, malformed Base64, and malformed URI.
- Structured-content vectors cover object, array, string, number, boolean, and null and validate as upstream `CallToolResult` values.
- Empty `content: []` is accepted by the shared complete tool-result schema.
- Generated `schemas/mcp/callToolResult.json` requires `content` and `resultType`, permits arbitrary `structuredContent`, and carries the constrained nested content schemas.

#### Review Slice 3: Metadata, Identity, Capabilities, And Extension Foundations

Implemented as seven separately reviewed checkpoints in `FrontmanProtocol__MCP.res`, the shared `FrontmanProtocol__MCPMetadata.res` boundary, generated schemas, and focused upstream verifier tests:

1. Added one shared metadata-object validator that preserves arbitrary JSON values while enforcing the normative key grammar, the frozen `64` immediate-key limit, and the frozen `16,384` compact UTF-8 byte limit.
2. Added the exact modern `Implementation` contract with required `name` and `version`, optional title, description, website URI, and reuse of the existing constrained content icon type and schema.
3. Added namespaced extension maps whose identifiers reuse metadata key validation with a mandatory prefix and whose values are JSON settings objects.
4. Added open `ClientCapabilities` validation for elicitation, experimental capabilities, extensions, roots, and sampling while preserving unknown capabilities unchanged.
5. Added open `ServerCapabilities` validation for completions, experimental capabilities, extensions, logging, prompts, resources, and tools while preserving unknown capabilities unchanged.
6. Added exact open request metadata with required protocol version and per-request client capabilities; optional implementation identity, logging level, and string-or-safe-integral local progress token; and lossless vendor metadata preservation.
7. Added exact open result metadata with optional server identity and lossless vendor metadata preservation, then applied it to complete tool results.

Implementation details:

- `FrontmanProtocol__MCPMetadata.res` owns generic metadata shape, grammar, limits, generated-schema constraints, and compact UTF-8 measurement.
- Request and result metadata validate their reserved fields without narrowing or discarding unknown valid metadata.
- The wire schema accepts any string protocol version so dispatch can return exact `UnsupportedProtocolVersionError` behavior instead of misclassifying an unsupported version as malformed JSON.
- Progress tokens reuse the shared string-or-safe-integral-number local JSON domain without adding progress notification state or advertising progress behavior.
- Client and server capability roots are dictionaries validated through known-field schemas rather than ReScript records because Sury record decoding discards unknown fields and MCP explicitly defines both capability sets as open.
- Official MCP extension identifiers under `io.modelcontextprotocol/` remain accepted by the generic extension map; the concrete Frontman execution-context contract separately proves that its own identifier uses the non-reserved `ai.frontman/` prefix.
- Complete tool-result metadata now uses `ResultMeta` rather than an unconstrained dictionary.
- Generated schemas now include `metaObject.json`, `implementation.json`, `extensions.json`, `clientCapabilities.json`, `serverCapabilities.json`, `requestMeta.json`, and `resultMeta.json`; metadata constraints also propagate into `callToolResult.json` and content-bearing dependent schemas.

Evidence:

- `VerifyMcpMetadata.test.mjs` proves valid and malformed key grammar, arbitrary JSON preservation, terminal line-separator rejection, and exact `64/65` key and `16,384/16,385` byte boundaries.
- `VerifyMcpImplementation.test.mjs` proves minimal and complete identity round trips, icon reuse, URI validation, required-field deletion, and malformed optional-field rejection.
- `VerifyMcpExtensions.test.mjs` proves mandatory prefixes, settings-object roots, official and vendor identifiers, arbitrary nested JSON settings, and generated-schema fidelity.
- `VerifyMcpClientCapabilities.test.mjs` and `VerifyMcpServerCapabilities.test.mjs` prove known-field validation, unknown-capability preservation, malformed-field rejection, and extension-identifier enforcement.
- `VerifyMcpRequestMeta.test.mjs` proves required-field deletion, every logging level, progress-token boundaries, malformed reserved-field rejection, vendor round trips, and request metadata limits including required keys.
- `VerifyMcpResultMeta.test.mjs` proves empty metadata, valid and malformed server identity, vendor round trips, metadata limits, and complete tool-result integration.
- Every locally emitted Slice 3 fixture within the pinned generated schema's accepted domain validates against the named upstream definition.
- Focused generated-schema tests compile each exported schema under JSON Schema 2020-12 and apply the same positive and negative vectors as runtime Sury validation.

#### Review Slice 4: Discovery, Tool Catalog, And Input-Response Foundations

Implemented as four separately reviewed checkpoints in the existing `FrontmanProtocol__MCP.res` owner, with minimal schema reuse changes in `FrontmanProtocol__ContentBlock.res`, generated schemas, and focused upstream verifier tests. No runtime dispatcher, caching engine, pagination loop, MRTR workflow, or tool execution behavior was added.

##### Checkpoint 4.1: Server Discovery

- Added exact `DiscoverRequest`, `DiscoverResult`, and `DiscoverResultResponse` wire schemas with required JSON-RPC constants, non-null string-or-safe-integral local IDs, required request metadata, open server capabilities, supported versions, optional instructions/result metadata, and required cache hints.
- Added shared `CacheScope` values for `private` and `public` and a non-negative integral cache TTL domain reaching `Number.MAX_SAFE_INTEGER` in positive tests.
- Preserved the upstream open-string `resultType` domain after independent review caught an initial incorrect narrowing to `"complete"`; Frontman-owned producers will emit `"complete"`, but shared parsers must not contradict the named upstream result schema.
- Kept the existing legacy `protocolVersion` constant and runtime dispatch unchanged because this checkpoint defines wire data only and is not an independently deployable cutover.

Evidence:

- `VerifyMcpDiscovery.test.mjs` round-trips all three official discovery fixtures and differentially validates runtime parsing and generated schemas against `DiscoverRequest`, `DiscoverResult`, and `DiscoverResultResponse`.
- Required-field deletion and wrong-type matrices cover both envelopes, required `_meta`, capabilities, versions, result type, TTL, cache scope, optional instructions, and optional result metadata.
- Cache vectors cover both scopes, zero, positive values, and the maximum safe JavaScript integer.
- Generated schemas are `discoverRequest.json`, `discoverResult.json`, and `discoverResultResponse.json`.

##### Checkpoint 4.2: Standard Tool Definitions

- Added the standard `Tool` contract with required `name` and object-rooted `inputSchema`; optional title, description, output schema, icons, annotations, and metadata; and no Frontman-private wire fields.
- Added open tool-annotation validation for standard title, destructive, idempotent, open-world, and read-only hints while preserving unknown hints unchanged. These hints remain untrusted data and do not drive authorization or execution policy.
- Reused the constrained icon and metadata owners rather than creating duplicate validation.
- Preserved arbitrary JSON Schema keywords. `inputSchema` requires root `type: "object"`; `outputSchema` remains an object containing any valid output schema, including a schema whose described instance root is an array.
- Deliberately did not narrow tool names to the recommended 1-128 character safe subset because the authoritative `Tool` schema accepts any string. Emitted Frontman catalogs still require a later policy check for the normative naming recommendations and uniqueness.

Evidence:

- `VerifyMcpTool.test.mjs` round-trips all six official Tool fixtures: default 2020-12 input, explicit draft-07 input, no parameters, composition, structured object output, and array output.
- The fixture oracle explicitly selects only default JSON Schema 2020-12 or the official draft-07 URI and throws for an unrecognized official-fixture dialect rather than silently treating it as 2020-12.
- Full metadata, icons, standard/unknown annotations, required-field deletion, wrong-type optional fields, invalid input roots, and the upstream broad tool-name string domain are covered.
- Generated `tool.json` matches the local runtime domain and validates the same vectors under AJV 2020-12.
- Full bounded validation of arbitrary untrusted schema keywords and declared dialects remains assigned to the Phase 3 and Phase 9 runtime validator. Pulling unbounded AJV compilation into this shared wire parser would violate the frozen schema-depth and network-reference limits.

##### Checkpoint 4.3: Tools List

- Added exact `ListToolsRequest`, `ListToolsResult`, and `ListToolsResultResponse` schemas with required request metadata, optional opaque cursor, Tool arrays, optional next cursor/result metadata, open result type, and required cache hints.
- Extracted discovery's identical TTL validation into one shared `CacheTtl` owner so discovery and list results cannot drift.
- Accepted absent, empty, and arbitrary string cursors exactly. Empty strings are valid cursors and must not be interpreted as end-of-pagination.
- Accepted empty Tool arrays while validating every populated entry through the standard Tool contract.
- Added wire support only. No server pagination machinery, page aggregation, freshness clock, cache key, invalidation, polling, or authorization-context cache was implemented.

Evidence:

- `VerifyMcpListTools.test.mjs` round-trips the official request, result, and response fixtures and validates local/generated/upstream agreement.
- Tests cover exact envelopes, required metadata shape, absent/empty/opaque cursors, empty catalogs, malformed tools, open core/vendor result types, both cache scopes, zero/wide TTLs, optional result metadata, and complete deletion/mutation matrices.
- Generated schemas are `listToolsRequest.json`, `listToolsResult.json`, and `listToolsResultResponse.json`.
- Independent review initially requested schema-level rejection of unsupported protocol-version strings; that request was declined because `RequestMetaObject` intentionally accepts any string and dispatch must return `UnsupportedProtocolVersionError` for a well-formed unsupported version.

##### Checkpoint 4.4: InputResponses Prerequisite

- Investigation of `CallToolRequestParams` showed that exact `tools/call` parsing depends on the complete optional `InputResponses` union, not merely `{name, arguments}`. The work was split at that dependency rather than introducing a permissive placeholder that would accept malformed MRTR retries.
- Added lossless pinned-schema shape validation for the three permitted `InputResponse` values: `ElicitResult`, `CreateMessageResult`, and `ListRootsResult`.
- Added elicitation action and form-value validation for strings, integral numbers, booleans, and string arrays while preserving wide integral values without ReScript `int` narrowing.
- Added sampling result validation for assistant/user roles, model, open stop reason, metadata, single or array text/image/audio/tool-use/tool-result content, complete standard content inside tool results, and arbitrary structured tool-result JSON.
- Added roots result validation with required URI, optional name, and metadata.
- Exposed the existing text, image, and audio component schemas from `FrontmanProtocol__ContentBlock.res` so sampling reuses the canonical validators without widening sampling content to resource links or embedded resources at its top level.
- Used a `preserveJsonWithSchema` boundary for heterogeneous official unions. It validates each value through Sury but returns the original JSON unchanged, preventing open extra fields or future-compatible data from disappearing during decode/encode.
- Added no MRTR retry, elicitation UI, sampling execution, roots execution, request-state parsing, or capability advertisement.

Evidence:

- `VerifyMcpInputResponses.test.mjs` round-trips the official combined InputResponses fixture plus every vendored ElicitResult, CreateMessageResult, and ListRootsResult example.
- Positive vectors cover all permitted response categories, empty roots, maximum-safe integral elicitation values, metadata-bearing values, tool-use arrays, and standard tool-result content.
- Negative vectors cover fractional/null/object elicitation values, invalid roles, forbidden top-level sampling resource links, malformed tool-use/tool-result blocks, missing model, malformed roots, unknown actions, and non-object response maps.
- Generated `inputResponses.json` compiles under AJV 2020-12 and applies the same nested unions and content constraints as runtime validation.
- Review slice 5 part 1 subsequently tightens Root values to the normative `file://` domain and records the pinned generated-schema discrepancy below.

#### Review Slice 5 Part 1: Normative Root URI Restriction

- Added a `ListRootsResult.fileUriSchema` refinement requiring the `file` scheme and `//` delimiter while retaining URI-format validation.
- Extended the generated schema with both `format: "uri"` and a case-insensitive-by-construction file-scheme pattern so runtime and generated validation enforce the same domain.
- Kept Roots deprecated, unadvertised, and non-operational; this change only validates Root-shaped values nested in interoperable `InputResponses`.
- Preserved both official `ListRootsResult` fixtures as positive local, generated, and upstream evidence.
- Added an uppercase-scheme positive vector per RFC 3986, negative HTTP and malformed-file vectors, and an explicit assertion that the pinned generated upstream `InputResponses` schema accepts an HTTP root despite the authoritative TypeScript source and specification prose requiring `file://`.

Documentation:

- [Roots / Root](https://modelcontextprotocol.io/specification/2026-07-28/client/roots#root) states that a Root URI must be a `file://` URI.
- [Immutable authoritative TypeScript schema](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/5f5440bb26a62e2cf3440b92da5a667efa03b267/schema/2026-07-28/schema.ts) states that `Root.uri` must start with `file://`.
- [RFC 3986 section 3.1](https://www.rfc-editor.org/rfc/rfc3986.html#section-3.1) defines URI schemes as case-insensitive, so receivers accept uppercase scheme spelling while producers should use lowercase.
- The pinned generated `Root` definition at `libs/frontman-protocol/test/mcp-upstream/schema.json` describes the requirement but encodes only `format: "uri"`; the focused discrepancy test prevents that omission from widening Frontman's accepted domain.

#### Review Slice 5 Part 2: Tools Call Request

- Added exact `CallToolRequestParams` and `CallToolRequest` schemas with required request metadata and tool name, optional object arguments, validated optional `InputResponses`, and optional opaque string request state.
- Reused the shared request metadata, JSON-RPC ID, and InputResponses owners so protocol-version metadata, capabilities, wide IDs, Root restrictions, and nested MRTR response validation cannot drift.
- Added generated `callToolRequestParams.json` and `callToolRequest.json` schemas.
- Kept the standard parameter object open as upstream defines it; `callId` is neither declared nor required, but unknown extra fields are not rejected by inventing a closed-object restriction.
- Added official request and parameter fixture round trips, complete required-field deletion and wrong-type matrices, absent/empty/nested argument vectors, wide IDs, retry input responses, opaque empty request state, open-object acceptance, and generated-schema proof that private `callId` is absent from the declared contract.
- Added wire support only. No dispatcher, execution, MRTR retry workflow, request-state interpretation, or legacy consumer cutover was implemented.

Documentation:

- [Tools / Calling Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools#calling-tools) defines the initial and MRTR retry request shapes.
- [Schema / CallToolRequest](https://modelcontextprotocol.io/specification/2026-07-28/schema#calltoolrequest) defines the exact envelope and required parameter fields.
- [MRTR / Client Requirements](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#client-requirements-basic-workflow) defines exact request-state echoing and independent retry IDs; this slice models those fields but adds no retry behavior.

#### Review Slice 5 Part 3A: List Roots Input Request

- Added the exact nested `ListRootsRequest` contract with required `method: "roots/list"`, optional params, and optional generic metadata.
- Used the existing lossless validated-JSON boundary because official nested request objects are open and the official fixture carries an undeclared `id`; accepted unknown fields survive wire round trip unchanged.
- Added generated `listRootsRequest.json` and focused official-fixture, absent-params, metadata, open-field, required-method, wrong-method, and malformed-params evidence.
- Added wire validation only. Roots remain deprecated and unadvertised, and no roots fulfillment or MRTR machinery was added.
- InputRequests union assembly and InputRequiredResult were completed subsequently in review slice 5 part 3D; the ElicitRequest and CreateMessageRequest variants are completed below.

Documentation:

- [MRTR / InputRequests](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#inputrequests) defines `ListRootsRequest` as one of exactly three permitted nested request variants.
- [Roots / Listing Roots](https://modelcontextprotocol.io/specification/2026-07-28/client/roots#listing-roots) defines the nested `roots/list` method shape.
- [Roots deprecation notice](https://modelcontextprotocol.io/specification/2026-07-28/client/roots) requires new implementations not to adopt Roots; structural recognition here does not advertise or fulfill it.

#### Review Slice 5 Part 3B: Elicitation Input Request

- Added exact lossless `ElicitRequest`, `ElicitRequestFormParams`, and `ElicitRequestURLParams` contracts for nested MRTR request recognition.
- Added the complete restricted `PrimitiveSchemaDefinition` union: string, number/integer, boolean, untitled/titled/legacy single-select enum, and untitled/titled multi-select enum shapes.
- Preserved open fields through validated JSON boundaries and retained wide non-negative integer-valued length/item bounds without ReScript `int` narrowing.
- Accepted omitted form mode as required for backward compatibility, validated URL mode through the shared URI owner, and did not invent an HTTPS-only wire restriction.
- Added four generated schemas and focused official-fixture, every-primitive-variant, omitted-mode, open-field, required-field, wrong-type, malformed-schema, nested-object, enum-array, negative/fractional bound, and invalid-URI evidence.
- Recorded that the pinned TypeScript and generated schemas type length/item bounds as integers without non-negative minima even though these are JSON Schema 2020-12 validation keywords; local runtime and generated schemas enforce the normative non-negative domain, and the focused test proves the upstream artifact discrepancy.
- Added shape recognition only. Frontman does not advertise elicitation, render forms, navigate URLs, collect sensitive data, fulfill requests, or retry automatically.

Documentation:

- [Elicitation / Elicitation Requests](https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation#elicitation-requests) defines form-mode omission and the form/URL union.
- [Elicitation / Requested Schema](https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation#requested-schema) defines the complete restricted primitive schema domain.
- [JSON Schema 2020-12 validation keywords](https://json-schema.org/draft/2020-12/json-schema-validation#name-validation-keywords-for-str) define length and item-count bounds as non-negative integers.
- [Elicitation / URL Mode](https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation#url-mode-elicitation-requests) defines required URL-mode fields and URI validation.
- [MRTR / InputRequests](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#inputrequests) identifies ElicitRequest as one of the three permitted nested request variants.

#### Review Slice 5 Part 3C: Sampling Input Request

- Added exact lossless `CreateMessageRequest` and `CreateMessageRequestParams` contracts with required messages and integral max tokens plus every standard optional sampling field.
- Added SamplingMessage, ModelPreferences, ModelHint, and ToolChoice contracts while reusing shared content, metadata, Tool, priority, and wide-integer owners.
- Preserved single-versus-array content and open fields at the wire boundary while normalizing content only inside the semantic validator.
- Added role-sensitive runtime validation requiring tool uses on assistant messages, tool results on user messages, result-only user messages, immediate adjacency, and one matching result per tool-use ID.
- Added six generated schemas and focused official-fixture, direct nested/open-contract round trips, optional-domain, priority boundary, wide max-token, required-field, wrong-type, message-content, tool-choice, and invalid tool-sequence evidence.
- Recorded that upstream and generated JSON Schemas validate only structure and cannot express cross-message tool sequencing; focused tests prove semantic-invalid vectors remain structurally accepted while local runtime validation rejects them.
- Added shape and semantic recognition only. Sampling remains deprecated and unadvertised; no model call, prompt retention, provider adaptation, tool execution, or fulfillment machinery was added.

Documentation:

- [Sampling / Creating Messages](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling#creating-messages) defines the nested request and parameter fields.
- [Sampling / Messages](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling#messages) defines roles and permitted content.
- [Sampling / Tool Result Messages](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling#tool-result-messages) requires result-only user messages.
- [Sampling / Tool Use and Result Balance](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling#tool-use-and-result-balance) requires adjacent one-to-one tool result matching.
- [Sampling deprecation notice](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling) requires new implementations not to adopt Sampling; structural recognition here does not advertise or fulfill it.

#### Review Slice 5 Part 3D: Input Requests And Input-Required Result

- Added the exact `InputRequest` union and string-keyed `InputRequests` map from the completed `CreateMessageRequest`, `ListRootsRequest`, and `ElicitRequest` contracts.
- Added lossless `InputRequiredResult` recognition with required `resultType: "input_required"`, optional result metadata, opaque string `requestState`, and the normative requirement that at least one of `inputRequests` or `requestState` is present.
- Preserved open fields at every nested request and result boundary while validating all known fields through their existing canonical schemas.
- Added generated `inputRequests.json` and `inputRequiredResult.json` schemas whose structural domains match runtime recognition, including the three-variant request union and the at-least-one-field result requirement.
- Recorded that the pinned generated upstream `InputRequiredResult` schema accepts arbitrary string result types and permits both `inputRequests` and `requestState` to be absent even though the base protocol and MRTR requirements prohibit both cases. Focused tests prove the discrepancy while local runtime and generated schemas enforce the normative domain.
- Added recognition only. Frontman does not advertise Roots, Elicitation, or Sampling; fulfill input requests; inspect request state; or automatically retry the original request.

Documentation:

- [MRTR / InputRequests](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#inputrequests) defines the map and its exact three request variants.
- [MRTR / InputRequiredResult](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#inputrequiredresult) defines optional input requests and opaque request state.
- [MRTR / Server Requirements](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr#server-requirements-basic-workflow) requires at least one of `inputRequests` or `requestState` and restricts request values to the three standard variants.
- [Base Protocol / ResultType](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#resulttype) defines `input_required` as the core discriminator for an `InputRequiredResult` and requires clients to reject unrecognized result types.

#### Review Slice 5 Part 3E: Cancellation Notification Contract

- Added lossless `CancelledNotificationParams` and `CancelledNotification` contracts with required string-or-safe-integral `requestId`, optional reason, exact `notifications/cancelled` method, exact JSON-RPC version, and no envelope ID.
- Added `NotificationMeta` as the bounded generic metadata domain plus optional string-or-safe-integral `io.modelcontextprotocol/subscriptionId`, preserving valid vendor metadata unchanged.
- Reused the existing abstract JSON-RPC ID schema for both cancellation request IDs and subscription IDs, so string/numeric preservation and fractional/null rejection cannot drift.
- Added generated `cancelledNotification.json`, `cancelledNotificationParams.json`, and `notificationMeta.json` schemas with matching structural constraints. The runtime-only compact UTF-8 metadata byte limit cannot be represented by JSON Schema and is covered as an explicit procedural boundary.
- Recorded that the pinned generated `CancelledNotification` schema accepts an `id` property even though the base protocol forbids IDs on notifications, and that the pinned generated `NotificationMetaObject` omits the normative generic metadata key constraints. Focused tests prove both artifact discrepancies while local runtime and generated schemas enforce the normative domain.
- Added wire support only. No sender registry, timeout, abort signal, transport disconnect handling, response suppression, subscription machinery, cancellation logging, or UI state was added.

Documentation:

- [Cancellation / Cancellation Flow](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation#cancellation-flow) defines the exact notification method, request ID, and optional reason.
- [Cancellation / Behavior Requirements](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation#behavior-requirements) limits cancellation to previously issued requests believed to remain in progress; enforcement belongs to later transport owners.
- [Cancellation / Transport-Specific Cancellation](https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation#transport-specific-cancellation) states that Streamable HTTP uses response-stream closure rather than this notification.
- [Base Protocol / Notifications](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#notifications) requires notifications to omit request IDs and receive no response.
- [Base Protocol / Notification metadata](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#meta) defines optional subscription IDs and applies the generic metadata key rules.

#### Review Slice 5 Part 3F: Accepted Streamable HTTP SSE Messages

- Added lossless shared JSON-RPC wire schemas for generic notifications, result responses, error responses, and the exclusive result-or-error response union in the existing `FrontmanProtocol__JsonRpc.res` owner.
- Added `StreamableHttpSseMessage` as exactly `JSONRPCNotification | JSONRPCResponse`; independent JSON-RPC requests are rejected as prohibited on modern Streamable HTTP response streams.
- Required exact JSON-RPC `2.0`, object notification params when present, non-null string-or-safe-integral local IDs on result responses, required result objects with `resultType`, optional IDs on generic error responses, and integral error codes with required messages.
- Preserved valid open fields and arbitrary error data losslessly while rejecting mixed notification/request/response discriminants and responses containing both result and error.
- Added generated `streamableHttpSseMessage.json` with the same structural union and focused official notification, tool-result response, and modern error-response evidence.
- Added only the decoded JSON message domain. SSE line framing, LF/CRLF handling, comments, split UTF-8, byte limits, stream termination, correlation, notification method/capability checks, and cancellation remain later browser transport work. Frontman servers still emit synchronous JSON only.

Documentation:

- [Streamable HTTP / Receiving Messages](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#receiving-messages) permits request-related notifications before the final response and forbids independent requests on the stream.
- [Base Protocol / Notifications](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#notifications) defines ID-less JSON-RPC notifications.
- [Base Protocol / Result Responses](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#result-responses) requires matching IDs, a result object, and `resultType`.
- [Base Protocol / Error Responses](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#error-responses) defines optional readable IDs, required error code/message, and integral error codes.
- [WHATWG Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html) governs framing and comment behavior but is intentionally not implemented in this shared decoded-message slice.

#### Review Slice 5 Part 3G: Modern Named Errors

- Added lossless named schemas for the five standard JSON-RPC errors: `ParseError` `-32700`, `InvalidRequestError` `-32600`, `MethodNotFoundError` `-32601`, `InvalidParamsError` `-32602`, and `InternalError` `-32603`.
- Added exact response-envelope schemas for the initially applicable MCP errors: `HeaderMismatchError` `-32020`, `MissingRequiredClientCapabilityError` `-32021`, and `UnsupportedProtocolVersionError` `-32022`.
- Required capability errors to carry `data.requiredCapabilities` through the open shared client-capabilities contract and version errors to carry string `data.requested` plus an array of string `data.supported` versions.
- Preserved open envelope, error, data, and capability fields losslessly while enforcing exact codes and required known fields.
- Exported eight focused generated schemas and added official-fixture, upstream-oracle, generated-schema, wrong-code, required-field deletion, nested-data mutation, open-field round-trip, and reserved-code inventory evidence.
- Added wire contracts only. HTTP `400` pairing, header validation, protocol-version dispatch, capability gating, runtime error construction, and removal of legacy constants remain assigned to later parts and phases.

Documentation:

- [Base Protocol / Error codes](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#error-codes) defines the standard JSON-RPC codes, the MCP-owned `-32020` through `-32099` range, and the prohibition on emitting undefined or legacy codes with modern meanings.
- [Base Protocol / Per-request capabilities](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#meta) defines `MissingRequiredClientCapabilityError`, code `-32021`, and its required capability data.
- [Versioning / Protocol version negotiation](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning#protocol-version-negotiation) defines `UnsupportedProtocolVersionError`, code `-32022`, and the required requested/supported version data.
- [Streamable HTTP / Protocol version header](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#protocol-version-header) and [custom header validation](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#server-behavior-for-custom-headers) define `HeaderMismatchError`, code `-32020`, and the later HTTP `400` behavior.
- The immutable pinned definitions and official examples are `ParseError`, `InvalidRequestError`, `MethodNotFoundError`, `InvalidParamsError`, `InternalError`, `HeaderMismatchError`, `MissingRequiredClientCapabilityError`, and `UnsupportedProtocolVersionError` in `libs/frontman-protocol/test/mcp-upstream/schema.json` and its `examples/` tree.

#### Review Slice 5 Part 3H: Generic JSON-RPC Requests And Message Classification

- Added a lossless generic `JSONRPCRequest` schema with exact `jsonrpc: "2.0"`, a required non-null string-or-safe-integral local ID, a required string method, and optional object-only params.
- Refined the shared numeric ID boundary to the inclusive JavaScript safe-integer range and encoded the same minimum and maximum in generated schemas, preventing distinct unsafe integers from collapsing before correlation.
- Reused the shared ID and open-object preservation boundaries so string/numeric ID type, both safe-integer limits, arbitrary nested parameter JSON, empty methods, and vendor envelope fields survive unchanged.
- Added the complete local `JSONRPCMessage` union over requests, notifications, result responses, and error responses.
- Extended the existing discriminant exclusions so requests reject result/error fields and every decoded message belongs to exactly one local message class.
- Exported focused `jsonRpcRequest.json` and `jsonRpcMessage.json` schemas and added official-fixture, upstream-oracle, generated-schema, required-field deletion, wrong-type, object-params, wide-ID, open-field, exact-classification, and malformed-message evidence.
- Recorded the open-upstream-union refinement explicitly: the pinned generated `JSONRPCMessage` schema accepts mixed request/response fields because its object branches are open, while Frontman's runtime and generated schemas reject ambiguous mixed discriminants.
- Added wire classification only. Method support, request metadata, capability and protocol-version dispatch, correlation, notification handling, and response construction remain consumer responsibilities.

Documentation:

- [Base Protocol / Messages](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#messages) requires all MCP messages to use JSON-RPC 2.0 and defines the request, notification, result-response, and error-response classes.
- [Base Protocol / Requests](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#requests) requires a non-null string or integer ID and defines optional structured parameters.
- [JSON-RPC 2.0 / Request Object](https://www.jsonrpc.org/specification#request_object) defines exact `jsonrpc`, method, structured params, and request-ID semantics.
- [ECMAScript `Number.isSafeInteger`](https://tc39.es/ecma262/#sec-number.issafeinteger) defines the exact numeric domain Frontman's JavaScript transports can preserve without integer aliasing; this is an explicit local implementation limit, not an MCP restriction.
- The immutable pinned `JSONRPCRequest` and `JSONRPCMessage` definitions and official request/notification/result/error examples are under `libs/frontman-protocol/test/mcp-upstream/`.

#### Review Slice 5 Part 3I: Frontman Execution Context Extension

- Defined the concrete `ai.frontman/execution-context` version `1` settings contract and proved that its reverse-DNS identifier is accepted by the shared extension and metadata grammar without using an MCP-reserved prefix.
- Added lossless required client-capability and server-capability schemas for bilateral extension advertisement while preserving unrelated extensions, capabilities, and settings fields.
- Added separate custom-Phoenix-transport schemas for compatible per-request client advertisement and request metadata carrying non-empty opaque `taskId` and durable `toolCallId` values. Keeping these schemas separate preserves the distinction between missing capability `-32021` and malformed context `-32602`.
- Kept the generic request metadata and Streamable HTTP contracts unchanged; only browser execution over the custom Phoenix transport requires this extension.
- Defined exact no-fallback behavior: absent or incompatible browser-server advertisement fails locally as `missing_required_server_extension` before `tools/call`; absent or incompatible per-request client advertisement returns standard `MissingRequiredClientCapabilityError` `-32021`; missing or malformed execution context returns a correlated standard `InvalidParamsError` `-32602` response.
- Kept context parsing separate from capability negotiation so absent client support cannot be misclassified as malformed context.
- Exported five generated schemas and added identifier/version, bilateral negotiation, open-field preservation, absent/incompatible advertisement, malformed context, upstream generic-domain, and exact standard-error evidence.
- Documented the extension's scope, settings, request metadata, lifecycle, errors, fallback prohibition, and security boundary in `docs/mcp/frontman-execution-context-extension.md`.
- Added the shared contract only. Discovery advertisement, per-request assembly, dispatcher validation, durable ownership, replay protection, cancellation wiring, and authorization remain consumer work.

#### Consumer Cutover And Structural Parity Evidence

- Updated the browser custom Phoenix dispatcher to validate modern request envelopes and metadata independently for discovery, list, and call; advertise and require execution-context version `1`; emit modern named errors and complete results; and structurally receive cancellation notifications.
- Updated the temporary Phoenix TaskChannel path to emit discovery, list, call, and cancellation values with modern metadata, correlate string or numeric response IDs, parse results by method, and retain complete result shape through persistence and replay.
- Deleted initialization-era MCP generated schemas and duplicate modern contract exports after active consumers moved to the existing shared MCP and JSON-RPC owners. ACP initialization remains a separate protocol and is not part of this deletion.
- Added `mcp-phase1-parity.json` as one shared deterministic fixture consumed by focused Node and Elixir tests. It covers discovery request/result, list request/result, execution-context-bearing call, complete result, unsupported-version named error, cancellation, and both request-ID wire types.
- Added a major changeset for `@frontman-ai/frontman-protocol` and `@frontman-ai/frontman-client`. No other package is named because this evidence slice establishes no additional public package API break.
- Kept cancellation claims structural: the browser receiver validates cancellation notifications, but does not correlate them, abort executing work, or prove late-response suppression.
- Did not implement or claim Streamable HTTP, framework dispatch, Phase 2 behavior, durable execution ownership, or full runtime cancellation.
- The evidence slice found that the shared ReScript `protocolVersion` export still said `2025-11-25`; the consumer-cutover follow-up corrected it to `2026-07-28`. Literal-version regression evidence remains part of the complete gate.

Documentation:

- [MCP statelessness](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#statelessness) requires explicit identifiers for state spanning requests and prohibits inferring conversation state from a connection.
- [MCP extension negotiation](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning#extension-negotiation) requires prefixed identifiers, bilateral capability advertisement, and documented fallback or rejection behavior.
- [MCP per-request metadata](https://modelcontextprotocol.io/specification/2026-07-28/basic/index#meta) requires client capabilities on every request and defines `MissingRequiredClientCapabilityError` for undeclared required capabilities.
- [Frontman execution-context extension](docs/mcp/frontman-execution-context-extension.md) freezes version `1` behavior and its no-fallback contract.

### Phase 1 Proof Status

| Proof criterion | Current status | Evidence or remaining work |
| --- | --- | --- |
| Emitted fixtures validate upstream | Passing | Focused official/shared fixtures and deterministic generated values pass current Node runtime schemas, generated schemas, and named upstream definitions. |
| Local accepted domain is an upstream subset | Passing with explicit authoritative-artifact discrepancies | Deterministic generation covers every domain named by the Phase 1 proof gate plus tool arguments and arbitrary structured content. Focused structural vectors cover the remaining implemented contracts. Safe numeric IDs and the concrete version `1` extension are intentional local subsets; Root, elicitation-bound, sampling-sequence, input-required discriminator/non-empty, notification-ID, notification-metadata, mixed-envelope, no-request-on-SSE, and recursive `JSONValue` differences have exact discrepancy tests and recorded source-of-truth decisions. |
| Required-field deletion fails | Passing for implemented Phase 1 contracts | Focused exhaustive matrices cover every implemented contract, and deterministic generation deletes required fields across request metadata, cancellation, Tool, tools/call, and complete tool results. |
| Wrong-type mutation fails | Passing for implemented Phase 1 contracts | Focused matrices cover shared domains, discovery/cache hints, tools/input envelopes, cancellation, generic messages, IDs, errors, extension settings/context, and wide integer boundaries. |
| Vendor and open fields round-trip | Passing at shared ReScript boundary for implemented contracts | Generic content metadata, request/result/notification metadata, generic and concrete extension settings/context, unknown capabilities, Tool annotations/metadata, list results, InputResponses, open nested requests, sampling contracts, cancellation, and generic SSE notification/result/error envelopes survive unchanged. Focused Phoenix tests prove `resultType` persistence; broader transport and application behavior remain. |
| Arbitrary structured JSON round-trips | Passing at shared ReScript boundary | Object, array, string, number, boolean, and null pass and validate upstream. Persistence, Elixir, ACP history, and model conversion remain. |
| IDs preserve type and value | Passing at shared and focused cross-language structural boundaries | Existing safe-integer boundary vectors remain, and the shared fixture gives both Node and Elixir the same string and numeric ID values. Broad transport correlation remains. |
| Sampling tool-use/result semantics | Passing at local runtime boundary | Runtime validation enforces role placement, result-only user messages, immediate adjacency, and bidirectional unique one-to-one ID matching. Focused tests explicitly prove these semantic failures remain structurally accepted by upstream/generated JSON Schemas. No sampling fulfillment is implemented. |
| Optional feature non-adoption | Passing for implemented shared shapes | Roots, Elicitation, Sampling, progress tokens, and MRTR retry fields are accepted only as required interoperable wire shapes. No capability advertisement, UI, model invocation, root lookup, URL navigation, progress engine, or automatic retry was added. |
| ReScript and Elixir fixtures match | Passing for the shared Phase 1 fixture | Both focused tests read the exact same JSON file and pass through their runtime and generated-schema boundaries. |

### Decisions And Lessons From Slices 1-5

- ReScript `int` and Sury `S.int` are unsuitable for MCP integer domains that are not explicitly signed 32-bit. They narrow runtime values and emit minimum/maximum constraints that do not exist upstream.
- JavaScript numeric IDs are accepted only in the inclusive safe-integer domain and generated schemas carry matching bounds; focused vectors prove both limits and reject the first unsafe integers even though the unrestricted upstream integer schema accepts them. Resource sizes retain the upstream unrestricted integral-number domain; later persistence and media limits must not be misrepresented as wire-schema constraints.
- Numeric identity restrictions must be enforced in the shared ID owner, not only in transport correlation code. Once an unsafe number has crossed JavaScript JSON decoding, distinct wire integers may already have aliased and no later comparison can repair the loss.
- A Sury transform over `S.json` exports `{}` unless the exact JSON Schema is attached with `extendJSONSchema`. Runtime validation and generated-schema fidelity must therefore be reviewed separately.
- Sury's decoded record representation may contain properties whose value is JavaScript `undefined`; wire round-trip tests normalize through JSON serialization before structural comparison because `undefined` properties are not JSON wire members.
- The pinned upstream `CallToolResult.structuredContent` field intentionally accepts any JSON value. It is not object-only.
- The pinned upstream `ResourceLink.size` field requires an integer but specifies no non-negative minimum. Local validation must not invent a minimum absent from the source of truth.
- The official content union contains exactly five top-level variants; embedded text and blob resources are alternatives inside the embedded-resource variant rather than additional top-level content types.
- Content `_meta` and embedded-resource `_meta` are objects. The former annotation placeholder was not a valid representation of official `Annotations`.
- Exact generated schemas propagate into ACP exports because ACP reuses the shared content owner. Regeneration must include every dependent schema, not only `schemas/mcp/callToolResult.json`.
- The smallest public ID API currently needed is parse-through-schema, `fromInt` for ACP, checked `toInt` for ACP, and `toJson`. Unused convenience constructors were removed rather than retained for hypothetical callers.
- Offline oracle and differential checks remain authored Node tests named `VerifyMcp*.test.mjs`, matching the accepted Phase 0 verifier infrastructure. ReScript runtime tests continue to use generated `*.test.res.mjs` artifacts.
- Review claims must be checked against the pinned artifact. Two automated-review claims were rejected because they contradicted the vendored schema: object-only structured content and a non-negative resource-size minimum.
- Generic metadata is a shared MCP boundary rather than a collection of per-record dictionaries. This is required so key grammar and frozen byte/key limits cannot drift between content, requests, and results.
- JavaScript regular-expression `$` can match before a terminal line separator. Metadata key validation therefore uses an explicit absolute-end guard, with newline, carriage return, U+2028, and U+2029 regression vectors.
- The normative metadata grammar permits an empty name, including an empty key or a prefix-only key such as `a/`. Automated-review requests to reject those values were declined because they contradicted the specification's explicit "unless empty" wording.
- Sury record parsing drops unknown object fields. Open MCP capability sets must validate known fields while returning the original dictionary unchanged; otherwise future and vendor capabilities disappear during round trip.
- Protocol-version schema validation accepts any string. Latest-only support is enforced by method dispatch with `-32022`, which preserves the distinction between malformed metadata and a well-formed unsupported version.
- Progress-token validation does not imply progress support. Frontman accepts strings and locally safe integral numbers through the shared ID domain but does not advertise or implement progress machinery.
- `clientInfo` and `serverInfo` are validated implementation identities only. They remain display/debugging data and cannot influence behavior, disambiguation, authentication, or authorization.
- The authoritative TypeScript and rendered schema define `JSONValue` as string, number, boolean, null, object, or array, but the pinned generated JSON Schema omits null and narrows numbers to integers inside recursive `JSONObject` values. Frontman follows the authoritative TypeScript/rendered contract and accepts recursive null and fractional values. `VerifyMcpExtensions.test.mjs` proves local/generated Frontman preservation and the exact pinned-upstream generated-schema rejection; this recorded exception remains until upstream corrects its generated artifact.
- Named discovery and tools-list result schemas expose `resultType` as an open string. Frontman-owned normal producers emit `"complete"`, but shared parsers must accept the upstream open domain; the first discovery implementation incorrectly narrowed it and independent review caught the mismatch.
- Required cache hints are one structural domain shared by discovery and list results. One `CacheTtl` validator now owns non-negative integral TTL validation, and `CacheScope` owns `private | public`; runtime freshness, cache keys, authorization isolation, and invalidation remain separate behavior.
- Empty pagination cursors are valid opaque tokens. Code must test option presence rather than string truthiness, and no decoder may parse or normalize cursor contents.
- Tool name safety and uniqueness are normative recommendations and server-emission policy, not restrictions in the authoritative Tool JSON Schema. The shared parser retains the upstream string domain; later catalog assembly must enforce deterministic names and collision policy without misrepresenting peer-schema validity.
- A Tool's `inputSchema` root must describe an object, while `outputSchema` is itself a schema object that may describe any JSON result root, including arrays. Object-only output assumptions are incorrect.
- Structural Tool wire parsing is not a safe arbitrary-schema runtime validator. Full declared/default dialect validation must use the bounded Phase 3/9 validator with schema depth limits and network/file/data reference loading disabled; compiling arbitrary peer schemas synchronously in this shared parser would create a denial-of-service boundary.
- Official Tool examples require both default JSON Schema 2020-12 and explicit draft-07 handling in verification. Test helpers must select recognized dialects explicitly and fail unknown dialects rather than silently defaulting them.
- Sury record fields are nominal. An attempted review simplification removing local known-field record declarations failed compilation and was reverted; those declarations are required for object-schema builders.
- `tools/call` cannot be modeled exactly as only name plus arguments. Its params include optional `InputResponses` and opaque `requestState`, so the complete InputResponse union is a prerequisite even though Frontman advertises no MRTR capabilities and implements no automatic retry machinery.
- Heterogeneous official unions can be validated losslessly by parsing through a typed Sury schema and returning the original `JSON.t`. This avoids both `Obj.magic` and field loss from record decoding while retaining exact generated-schema constraints.
- Sampling content is narrower than general MCP ContentBlock at its top level: text, image, audio, tool use, and tool result are permitted, but resource links and embedded resources are only valid inside tool-result content. Reusing the full top-level content union would be over-permissive.
- Review findings must be compared with executed evidence and the pinned contract. A claimed AJV `format: "byte"` compilation failure was rejected after the exact test suite passed with `ajv-formats`; a claimed protocol-version schema defect was rejected because dispatch-level `-32022` behavior requires the schema to accept well-formed unsupported strings.
- The Root definition contains a normative `file://` requirement not encoded by the pinned generated schema's generic URI constraint. Review slice 5 part 1 resolves this with matching local runtime and generated-schema restrictions plus an explicit upstream-discrepancy assertion; Roots remain deprecated and unadvertised.
- URI schemes are case-insensitive under RFC 3986 section 3.1. Root validation accepts `FILE://` and other scheme casing while producers should use canonical lowercase; a literal lowercase prefix test would incorrectly reject a valid URI.
- The legacy `toolCallParams` owner was deleted after consumer cutover. Modern `CallToolRequestParams` neither declares nor requires private `callId`; upstream parameter objects remain open, so an undeclared `callId` is structurally preserved as an unknown peer field rather than acquiring Frontman semantics.
- Open-object acceptance and lossless round trip are separate properties. A typed `S.object` may accept unknown fields but discard them during decode/encode. Open wire contracts that cross public boundaries use `preserveJsonWithSchema`, including nested MRTR requests, ModelHint, ModelPreferences, ToolChoice, and SamplingMessage.
- Official nested request fixtures can carry undeclared open fields. The official ListRootsRequest fixture includes `id` even though the named schema requires only `method`; lossless validators must preserve such fields rather than rebuilding a reduced record.
- Structural recognition of deprecated Roots and Sampling and optional Elicitation does not constitute feature adoption. Frontman must parse required core variants but must not advertise capabilities or add fulfillment, UI, navigation, model calls, root lookup, or retry machinery without a caller.
- `tools/call` request parameters include optional validated InputResponses and opaque requestState. Standard initial calls work without `callId`; MRTR retry field support in the wire schema does not authorize parsing requestState or implementing automatic retries.
- Elicitation form mode may omit `mode`; receivers must treat omission as form. URL mode requires a valid URI, but the wire schema does not impose HTTPS even though HTTPS is recommended outside development.
- JSON Schema 2020-12 length and item-count keywords require non-negative integers. The pinned TypeScript and generated schemas omit those minima, so local runtime/generated schemas enforce them and tests explicitly record that the upstream generated oracle accepts invalid negative values.
- ReScript nominal records with overlapping field names require explicit local type annotations in Sury object builders. Compilation caught ambiguity between titled/untitled multi-select schemas and normalized/lossless SamplingMessage records; removing these annotations is not a simplification.
- Sampling wire content accepts single or array text, image, audio, tool-use, and tool-result blocks. Single-versus-array shape and unknown fields remain lossless on the wire; normalization occurs only inside the semantic sequence validator.
- Sampling tool sequencing is normative behavior that JSON Schema cannot express. Runtime validation must reject wrong-role tool blocks, mixed tool-result user messages, missing or intervening results, unmatched IDs, duplicate tool-use IDs, and duplicate result IDs even though structural upstream/generated schemas accept those values.
- One-to-one ID comparison must prove equal cardinality, bidirectional membership, and uniqueness. Checking only that every expected ID appears once in results allows duplicate expected IDs to hide an unrelated result.
- `InputRequests` is an open string-keyed map, but every value is restricted to exactly `CreateMessageRequest`, `ListRootsRequest`, or `ElicitRequest`. An empty map is structurally valid; capability negotiation and whether requested inputs can be fulfilled are later behavior checks.
- `InputRequiredResult` recognition requires the core `input_required` discriminator and presence of at least one of `inputRequests` or opaque `requestState`. The pinned generated schema omits both restrictions, so local runtime/generated schemas enforce the normative prose and focused tests record the upstream artifact discrepancy.
- Cancellation `requestId` and notification `subscriptionId` are both the ordinary non-null string-or-safe-integral local `RequestId` domain. Runtime ownership checks determine whether an ID refers to active work; every JavaScript boundary must share the documented safe-integer restriction.
- Cancellation notification objects remain open for vendor fields but must reject an `id` member. The pinned generated schema's open object accepts `id`, so local runtime and generated schemas add the base-protocol notification prohibition explicitly.
- `NotificationMetaObject` extends the generic bounded metadata domain and optionally reserves `io.modelcontextprotocol/subscriptionId`. The pinned generated schema omits inherited generic metadata constraints, so local generated schemas restore key grammar and key count while runtime validation additionally enforces the frozen compact UTF-8 byte limit that JSON Schema cannot express.
- Streamable HTTP SSE `data:` carries complete JSON-RPC messages, not bare result values or private event payloads. The accepted decoded domain is notifications plus result/error responses; requests are rejected before method-specific handling.
- Generic wire response parsing preserves open fields but enforces mutually exclusive result/error discriminants. Generic structural acceptance does not authorize an unknown notification method or result type; pending-request and capability-aware consumers perform those semantic checks later.
- Generic error codes use integral JavaScript numbers rather than ReScript `int`, avoiding signed 32-bit narrowing before the named modern error slice applies code-specific meaning.
- Capability negotiation and extension payload validation are different protocol failure classes. Parse generic required metadata first, check required client capability next, and validate extension context only after compatible advertisement so missing support returns `-32021` rather than being absorbed into `-32602`.
- A client-side failure discovered from server capabilities is local state, not a peer JSON-RPC error. The execution-context contract uses the stable local `missing_required_server_extension` classification and forbids fabricating a JSON-RPC response that the browser never emitted.
- Independent review is advisory, not authoritative. Earlier Slice 5 reviews accepted real findings for URI scheme casing, open-contract evidence, required-field mutation coverage, non-negative JSON Schema bounds, duplicate sampling IDs, traceability precision, and nested-schema losslessness; each correction was rerun through the full protocol gate.
- Review slice 5 part 3D passed independent review without findings after proving exact InputRequests variants, the InputRequiredResult discriminator/non-empty invariant, lossless open fields, and no fulfillment behavior.
- Review slice 5 part 3E initially received one medium finding: generated JSON Schema cannot encode the runtime `16,384` compact UTF-8 metadata byte limit, while the plan overstated runtime/generated alignment and lacked a cancellation-specific boundary vector. The plan now records this procedural limit explicitly, focused tests prove `16,384/16,385` runtime behavior and the generated-schema limitation, and resumed independent review passed.
- Review slice 5 part 3F passed independent review without findings after checking notification/response-only SSE acceptance, independent-request rejection, discriminant exclusivity, optional error IDs, wide integral error codes, lossless open fields, and strict separation from framing/parser behavior.
- Review slice 5 part 3G initially received three evidence findings: required-field deletion did not cover every required envelope/error field, open client capabilities were not exercised inside the capability error, and the reserved-code inventory was derived only from test fixtures. The test matrix now deletes every required field, round-trips an unknown nested capability, and checks the centralized production `ModernErrorCode.mcpReserved` inventory against the three MCP contracts; resumed independent review passed. Runtime dispatch and HTTP status behavior remain explicitly outside this structural checkpoint.
- Review slice 5 part 3H initially received one high finding: the inherited numeric ID parser accepted unsafe JavaScript integers that cannot be correlated losslessly. The shared ID schema now uses the inclusive ECMAScript safe-integer domain, generated schemas carry matching bounds, implementation limits document the upstream-compatible narrowing, and focused tests reject both first unsafe integers while proving upstream accepts them; resumed independent review passed. Generic request validation and the four-class decoded-message union otherwise preserve the distinction between upstream structural openness and Frontman's required unambiguous local classification.
- Review slice 5 part 3I initially received one high, one medium, and one low finding: combined context/capability parsing would misclassify missing negotiation as `-32602`, missing browser-server support lacked an exact local failure, and malformed-context evidence covered only a bare error object. Context parsing and capability negotiation are now separate, missing server support uses the stable non-protocol `missing_required_server_extension` classification, and malformed context proves a correlated `-32602` response; resumed independent review passed.

Authoritative definitions used directly by these slices:

- `RequestId`, `JSONRPCRequest`, `JSONRPCNotification`, `JSONRPCResultResponse`, `JSONRPCErrorResponse`, and `JSONRPCResponse` in `libs/frontman-protocol/test/mcp-upstream/schema.json`.
- `Annotations`, `ContentBlock`, `TextContent`, `ImageContent`, `AudioContent`, `ResourceLink`, `EmbeddedResource`, `TextResourceContents`, and `BlobResourceContents` in the same pinned schema.
- `CallToolResult`, whose `structuredContent` property has no object-only type restriction and whose required fields are `content` and `resultType`.
- `MetaObject`, `RequestMetaObject`, `ResultMetaObject`, `Implementation`, `ClientCapabilities`, `ServerCapabilities`, `LoggingLevel`, `ProgressToken`, and `Icon` in the pinned schema and rendered `2026-07-28` schema reference.
- `DiscoverRequest`, `DiscoverResult`, `DiscoverResultResponse`, `Tool`, `ToolAnnotations`, `ListToolsRequest`, `ListToolsResult`, `ListToolsResultResponse`, `CallToolRequest`, `CallToolRequestParams`, `InputRequest`, `InputRequests`, `InputRequiredResult`, `InputResponse`, `InputResponses`, `ElicitResult`, `CreateMessageResult`, `ListRootsResult`, `Root`, `ListRootsRequest`, `ElicitRequest`, `ElicitRequestFormParams`, `ElicitRequestURLParams`, `PrimitiveSchemaDefinition`, `CreateMessageRequest`, `CreateMessageRequestParams`, `SamplingMessage`, `SamplingMessageContentBlock`, `ModelHint`, `ModelPreferences`, `ToolChoice`, `ToolUseContent`, and `ToolResultContent` in the pinned schema and rendered reference.
- `CancelledNotification`, `CancelledNotificationParams`, and `NotificationMetaObject` in the pinned schema, plus the rendered cancellation and base notification requirements where the generated artifact omits inherited or negative constraints.
- `ParseError`, `InvalidRequestError`, `MethodNotFoundError`, `InvalidParamsError`, `InternalError`, `HeaderMismatchError`, `MissingRequiredClientCapabilityError`, and `UnsupportedProtocolVersionError` in the pinned schema and official examples.
- The `_meta` key grammar and per-request/per-response field requirements in the base protocol, plus extension negotiation's mandatory-prefix rule.
- Traceability requirements RPC-003, RPC-005, and RPC-011 in `docs/mcp/traceability/base-versioning.md` for non-null request IDs and response ID preservation.
- Traceability requirements META-001, META-002, META-004, META-005, META-008, META-012 through META-014, and EXT-001 in `docs/mcp/traceability/base-versioning.md`, plus the structural metadata and capability requirements referenced by the Slice 3 verifier fixtures in `docs/mcp/traceability/tools-discovery.md`; dispatch, HTTP status, capability-gating, and identity-behavior requirements remain planned for later phases.

### Verification Record For Slices 1-5

Latest verification completed on `2026-08-10`, including deterministic differential generation and final Phase 1 review:

- Latest `make -C libs/frontman-protocol mcp-verify`: `116` verifier tests passed, all `129` official examples validated, and all `443` traceability requirement IDs structurally verified.
- `VerifyMcpProperty.test.mjs` passed the required `1,000` pull-request profile and the configured `10,000`-case scheduled profile locally with reproducible seed `20260728`; the focused target verifies oracle checksums before executing generated differential cases.
- `.github/workflows/mcp-property.yml` supplies the weekly/manual `10,000`-case hosted gate. Its first hosted execution remains observable CI evidence rather than a prerequisite for the locally completed Phase 1 proof, and cached per-definition upstream validators keep the full local run below two seconds.
- Protocol build and schema export passed; `85` JSON-RPC, MCP, Relay, and dependent ACP schemas were exported. Slice 5 added tools-call, nested input, cancellation, complete generic message classification, accepted SSE messages, modern named errors, execution-context contracts, and their shared supporting schemas while preserving propagated constraints.
- Focused Slice 3 tests compile generated schemas with AJV JSON Schema 2020-12 and compare runtime parsing, generated-schema validation, and named upstream definitions where the pinned generated artifact matches the authoritative type.
- Metadata boundary tests pass exact `64/65` immediate-key and `16,384/16,385` compact UTF-8 byte vectors for generic, request, result, and notification/cancellation metadata. Generated schemas enforce key grammar and count; compact serialized byte size remains a documented runtime-only procedural constraint.
- Independent review checkpoints found the identity, extension, server-capability, request-metadata, and result-metadata contracts aligned after one real terminal-line-separator regex defect was fixed; repeated requests to reject spec-permitted empty metadata names were declined with normative evidence.
- Slice 4 independent review caught the real discovery `resultType` narrowing defect, which was fixed. Tool review clarified structural wire parsing versus the later bounded runtime schema validator and tightened fixture dialect selection. List review added explicit open-result-type coverage while preserving dispatch-level protocol-version handling. InputResponses review passed after executed AJV evidence disproved a false format-registration concern; Slice 5 then resolved the separate normative Root restriction.
- Slice 5 independent reviews caught and drove fixes for case-insensitive URI schemes, missing open-object and required-field mutation evidence, negative JSON Schema bounds, duplicate sampling-ID matching, semantic-versus-structural traceability wording, lossless nested open contracts, compact metadata byte-limit overstatement, incomplete named-error evidence, unsafe numeric IDs, capability/context error conflation, and ambiguous local extension failure semantics. Every corrected checkpoint passed its resumed independent review; Parts 3D and 3F passed without findings.
- `VerifyMcpCallToolRequest.test.mjs`, `VerifyMcpListRootsRequest.test.mjs`, `VerifyMcpElicitRequest.test.mjs`, and `VerifyMcpCreateMessageRequest.test.mjs` add official fixtures, generated-schema validation, upstream differential checks, required-field deletion, wrong-type and boundary vectors, open-field round trips, explicit artifact-discrepancy assertions, and runtime-only sampling semantic checks for Slice 5.
- `VerifyMcpInputRequests.test.mjs` adds official InputRequests and InputRequiredResult fixtures, all three nested request variants, empty/open map behavior, opaque state and metadata preservation, malformed nested values, and explicit generated-artifact discrepancy assertions for the core discriminator and at-least-one-input requirement.
- `VerifyMcpCancellation.test.mjs` adds official cancellation fixtures, the shared string/safe-integral ID domain, lossless open fields, notification metadata/subscription IDs, complete deletion and wrong-type vectors, exact runtime compact UTF-8 byte boundaries, and explicit generated/artifact discrepancy assertions for forbidden envelope IDs and metadata constraints.
- `VerifyMcpSseMessage.test.mjs` adds official progress-notification, tool-result-response, and modern-error fixtures; lossless open fields; safe-range IDs and wide integral error codes; ID-less errors; independent-request rejection; required-field and wrong-type vectors; and exclusive result/error classification.
- `VerifyMcpNamedErrors.test.mjs` adds all eight named contracts, every available official fixture, local/generated/upstream agreement, complete required-field deletion, exact-code and nested-data mutations, open-field and open-capability round trips, and centralized MCP-reserved code inventory evidence.
- `VerifyMcpJsonRpcMessage.test.mjs` adds all four official message classes, lossless request round trips, optional object-params coverage, complete request-field deletion, malformed and mixed envelopes, exact class exclusivity, both safe numeric ID limits, and explicit upstream/local evidence for unsafe-ID and mixed-discriminant refinements.
- `VerifyMcpExecutionContextExtension.test.mjs` adds exact identifier/version settings, bilateral capability negotiation, unrelated-field preservation, separate capability/context classification, required context identifiers, absent/incompatible/malformed vectors, exact standard peer errors, and the stable local missing-server-support failure.
- `VerifyMcpPhase1Parity.test.mjs` passes two focused tests over the shared fixture, round-tripping all eight values through current Sury runtime schemas and generated JSON Schemas and proving both string and numeric IDs.
- `mcp_phase1_parity_test.exs` reads that same fixture and validates all eight values through `ProtocolSchema`, exact-compares emitted discover/list/call/cancellation values with `ModelContextProtocol`, and parses discovery/list/call/named-error responses.
- `jq empty libs/frontman-protocol/test/fixtures/mcp-phase1-parity.json`, `yarn changeset status`, the standalone traceability verifier, and `git diff --check` pass. Changesets recognizes major bumps for the two explicitly named packages; dependent workspace patch propagation is computed by Changesets rather than added as an asserted public break.
- Final serial package evidence: `libs/frontman-client` passed `94` tests after a clean compiler-state rebuild, `libs/frontman-core` passed `321`, `libs/client` passed all `319` authored tests, and `apps/frontman_server` passed all `730` tests.
- Repository source-comment verification passed with `30` scanner tests and zero prohibited authored-source comments.
- ReScript formatting passed for `FrontmanProtocol__MCP.res`, `FrontmanProtocol__JsonRpc.res`, and `ExportSchemas.res`; Slice 5 through Part 3I compiled successfully, all `85` generated schemas are current, and no formatter suppressions or source comments were introduced.
- `git diff --check` passed.
- `libs/client`: all `319` authored tests pass after deleting three orphaned generated test modules whose ReScript sources no longer exist.
- `apps/frontman_server`: all `730` tests pass. Tool-result persistence preserves `resultType`, structured content, and open top-level fields while scrubbing result `_meta` before storage.

### Build And Test Harness Findings

- ReScript packages share build artifacts across the workspace. Parallel clean/build operations can delete or invalidate another package's generated modules; package verification must run serially until the build topology is isolated.
- `libs/client` and `libs/frontman-client` clean targets now run `rescript clean`, preventing orphaned generated tests and compiler-state/output mismatches. Clean rebuilds pass both suites.
- A prior attempt to build multiple ReScript packages in parallel reproduced the known inconsistent-interface and missing-artifact failures. Subsequent protocol, frontman-client, and frontman-core acceptance evidence was collected serially.

### Phase 1 Acceptance And Later Cleanup

Consumer inventory/cutover, initialization-era MCP schema deletion, focused shared structural fixtures, deterministic differential generation, the recursive `JSONValue` discrepancy decision, final cleanup searches, and the breaking changeset are complete. Phase 1 is accepted. The items below remain assigned to their owning later runtime phases rather than blocking this wire-contract checkpoint.

- Modern named errors are complete in `FrontmanProtocol__MCP.res` and the custom-Phoenix browser dispatcher constructs them; HTTP status/error dispatch remains later transport work.
- Use the completed open client/server capability contracts in discovery and per-request metadata assembly while advertising only Frontman's implemented initial feature set.
- Generic JSON-RPC request fidelity and exclusive four-class message recognition are complete in `FrontmanProtocol__JsonRpc.Wire`; custom-Phoenix consumers now use those owners.
- The version `1` execution-context settings, bilateral capability, custom-transport request metadata, and no-fallback error contracts are complete and used by the custom-Phoenix consumers; durable ownership remains later work.
- Cancellation-ID validation and a structural browser receiver are complete. Actual abort, resource release, response suppression, timeout integration, and UI state remain later runtime work; no optional progress machinery may be added.
- Keep SSE framing, LF/CRLF handling, comments, split UTF-8, reader cancellation, response-byte limits, terminal-response handling, and correlation assigned to the Phase 3 browser transport; Part 3F completed only the decoded message domain.
- Add runtime Tool JSON Schema validation only at the bounded Phase 3/9 trust boundary; enforce default 2020-12, explicitly supported dialects, schema depth, no network reference resolution, and individual invalid-tool exclusion.
- Keep the accepted deterministic differential/property suite and every authoritative-artifact discrepancy test in the pull-request gate; expand generators when later phases add locally accepted domains.
- Keep repository cleanup searches in every later phase. ACP initialization remains intentionally unrelated, and private Relay fields remain until their Phases 2-3 deletion.
- Keep the existing major changeset scoped to the two public packages whose contract broke; add no incidental package bumps without a public API break.

## Phase 2: Framework Streamable HTTP Server

### Work

Replace these custom relay endpoints:

```text
GET  /frontman/tools
POST /frontman/tools/call
```

with:

```text
POST /mcp
```

Implement:

- `server/discover`.
- `tools/list`.
- `tools/call`.
- JSON responses for synchronous calls.
- Stream-close cancellation.
- Deterministic tool ordering.
- One complete tools page with no cursor while the Frontman-owned catalog fits the documented limit.
- Required caching metadata.
- Exact method-specific errors.
- `x-mcp-header` tool schema handling.

Do not implement or expose:

- `initialize`.
- `notifications/initialized`.
- GET streams.
- MCP sessions.
- SSE resumability.
- `Last-Event-ID` behavior.
- Standalone server-to-client JSON-RPC requests.
- `subscriptions/listen` until fully implemented and needed.
- Emitted progress notifications or SSE responses until a real Frontman tool produces progress or streamed output.
- Server-side pagination until a real catalog exceeds the documented single-page limit.

Initially advertise:

```json
{
  "tools": {
    "listChanged": false
  }
}
```

Use `ttlMs: 0` initially so clients revalidate when the catalog is next needed. Increase TTL only after tool-catalog stability and invalidation behavior are proven.

Use `cacheScope: "private"` whenever results depend on authorization, user, project, plugin set, or runtime context. Use `public` only when identical results are provably safe to share across authorization contexts.

### Request Validation Order

1. Recognize that the request targets `/mcp` without producing method-specific behavior.
2. Validate Origin before method handling, authentication-sensitive responses, parsing, or execution.
3. Apply authentication and authorization.
4. Validate `Content-Type`.
5. Validate `Accept` negotiation.
6. Enforce body size.
7. Decode one UTF-8 JSON value.
8. Validate JSON-RPC envelope and direction.
9. Validate required MCP headers.
10. Compare headers with body values.
11. Validate protocol version and client capabilities.
12. Validate method parameters.
13. Select the requested tool.
14. Validate tool arguments through the selected tool's existing Sury schema.
15. Execute only after all protocol validation succeeds.

Tool input-schema failure is a tool execution error under SEP-1302. Return a successful JSON-RPC response containing a complete `CallToolResult` with `isError: true`; do not return JSON-RPC `-32602`. Reserve `-32602` for malformed method parameters and unknown tools.

### Required Headers

Every POST requires:

```text
MCP-Protocol-Version: 2026-07-28
```

Every JSON-RPC request additionally requires `Mcp-Method: <json-rpc-method>`. The 2026 core defines no client-to-server Streamable HTTP notifications, so do not invent notification header requirements.

`tools/call`, `resources/read`, and `prompts/get` require `Mcp-Name`.

Tools using `x-mcp-header` require matching `Mcp-Param-*` headers.

Header names are case-insensitive. Method and name values are case-sensitive. Values that are not safe plain ASCII use the specification's exact Base64 sentinel encoding.

### Response And Status Matrix

| Condition | HTTP status | JSON-RPC behavior |
| --- | ---: | --- |
| Successful request | 200 | Result or method-level error envelope |
| Accepted notification | 202 | Empty body |
| Invalid Origin | 403 | Optional ID-less JSON-RPC error |
| Missing authentication | 401 | Optional JSON-RPC error |
| Insufficient authorization | 403 | Optional JSON-RPC error |
| Unsupported media type | 415 | Optional JSON-RPC error |
| Unacceptable response media | 406 | Optional JSON-RPC error |
| Malformed JSON | 400 | `-32700` |
| Invalid JSON-RPC request | 400 | `-32600` |
| Invalid method params or unknown tool | 200 | `-32602` |
| Selected tool rejects arguments | 200 | Complete result with `isError: true` |
| Unknown method | 404 | `-32601` |
| Header/body mismatch | 400 | `-32020` |
| Missing required client capability | 400 | `-32021` |
| Unsupported protocol version | 400 | `-32022` with supported versions |
| GET or DELETE `/mcp` | 405 | Frontman policy sets `Allow: POST, OPTIONS` |

Verify exact status requirements against the normative Streamable HTTP text during implementation. The traceability matrix wins over this summary if upstream wording differs.

### Deferred Server SSE Requirements

The initial Frontman server emits JSON only. The browser client must still accept standards-compliant SSE from interoperable remote servers. If a later feature introduces a real Frontman progress or streaming producer, implement server SSE in that feature and apply these requirements:

SSE `data:` fields carry complete JSON-RPC notifications and the final JSON-RPC response. Do not send bare result objects or custom `event: result` and `event: error` payloads.

Required behavior:

- Support LF and CRLF framing.
- Ignore SSE comments.
- Handle UTF-8 sequences split across chunks.
- Emit only notifications related to the originating request.
- Never emit independent server requests.
- Follow the specification recommendation to terminate after the final response.
- Apply the Frontman transport policy `X-Accel-Buffering: no`.
- Treat response-stream closure as cancellation.
- Stop cancellable work as soon as practical and emit no later messages after cancellation.

### Proof Gate

- Black-box tests exercise the actual HTTP boundary.
- Every header/status combination has positive and negative coverage.
- Base64 sentinel edge cases pass.
- JSON response mode passes; server SSE tests become applicable only when emitted SSE is implemented.
- Cancellation races pass.
- Invalid requests cause no tool side effect.
- Official Streamable HTTP conformance tests have no accepted failures.

## Phase 3: Browser Streamable HTTP Client

### Work

Replace `FrontmanClient__Relay` with a standard Streamable HTTP MCP client.

Responsibilities:

- Target `POST /mcp`.
- Send full JSON-RPC envelopes.
- Send required body metadata and HTTP headers.
- Support string and numeric IDs.
- Call `server/discover` and verify `2026-07-28` support.
- Fetch all `tools/list` pages.
- Detect repeated cursors and enforce page/tool limits.
- Cache by endpoint, authorization context, protocol version, method, and effective parameters.
- Respect `ttlMs` and `cacheScope`.
- Revalidate stale data on demand, not through automatic polling.
- Validate tool definitions and JSON Schema dialects.
- Reject malformed `x-mcp-header` definitions without rejecting valid sibling tools.
- Generate and encode all mirrored headers.
- Accept `application/json` and `text/event-stream` responses.
- Validate response IDs and terminal response uniqueness.
- Cancel fetch, stream reader, and local processing using `AbortController`.
- Ignore late responses after cancellation.

The client must not automatically dereference network `$ref` values. Any future opt-in resolver requires an allowlist, DNS/IP checks, timeouts, byte limits, redirect controls, and SSRF tests.

### Proof Gate

- Tests run against a real in-process HTTP server rather than replacing `fetch`.
- Discovery, pagination, caching, private-cache isolation, headers, JSON, SSE framing, cancellation, malformed streams, and reconnects pass.
- A stale `x-mcp-header` definition triggers relisting and one bounded retry where the specification recommends it.
- No authorization-sensitive response is reused across authorization contexts.

## Phase 4: Browser MCP Server On Custom Phoenix Transport

### Work

Keep Phoenix `mcp:message` as a custom MCP transport while replacing legacy semantics.

Document the custom binding:

- Connection establishment.
- Authentication and authorization inheritance.
- One Phoenix payload equals one JSON-RPC message.
- Message encoding.
- Allowed direction of requests, responses, and notifications.
- Ordering and delivery assumptions.
- Individual request cancellation.
- Connection teardown behavior.
- Retry and replay behavior.
- Size and rate limits.

Remove:

- `initialize` handling.
- `notifications/initialized` handling.
- Connection-scoped negotiated state.
- Task identity inferred from the channel topic.
- Required `callId` in `tools/call` params.
- Silent `Suspended` outcomes.

Implement:

- Mandatory `server/discover`.
- Independent `_meta` validation for every request.
- One deterministic `tools/list` page with required caching fields and no cursor while the catalog remains below the documented limit.
- `tools/call` complete results.
- Full error codes and data.
- Request cancellation.
- In-flight request tracking.
- Late-response suppression.
- Deterministic standard tool serialization.
- Explicit Frontman extension metadata.

Reject `input_required` as unsupported and do not advertise the corresponding optional capability. Add MRTR only through the separately approved feature described in Phase 8.

Hidden tools are filtered before serialization. Do not expose `visibleToAgent` as a core field.

Map access conservatively to standard annotations:

- Read-only tools may set `readOnlyHint: true`.
- Writing tools set `readOnlyHint: false`.
- Do not infer destructive, idempotent, or open-world hints without tool-specific evidence.

### Proof Gate

- The custom transport contract is documented and tested on both peers.
- Invalid frames never reach tool execution.
- Every request validates its own version and capabilities.
- Concurrent requests cannot leak context.
- Detaching one channel cannot remove another handler.
- Cancelled or disconnected requests cannot send late responses.
- Every standard tool result content type passes.

## Phase 5: Existing Phoenix Connection Owner

### Work

Move MCP request ownership out of task-specific `TaskChannel` processes into the existing authenticated connection-wide `FrontmanServerWeb.TasksChannel` process. Do not add a broker GenServer or another Phoenix channel.

```text
TaskChannel observers ----\
ToolExecutor ------------- existing TasksChannel ---- browser MCP server
```

The existing `TasksChannel` owns:

- `server/discover`.
- The current one-page tool catalog and its caching metadata.
- Request ID generation.
- Pending request correlation.
- Request kind and method-specific parsing.
- Absolute request deadlines.
- Cancellation.
- Minimal bounded tracking needed to reject cancelled, completed, duplicate, or late response IDs.
- Connection teardown.
- Tool-execution ownership references.

Use the smallest existing registration mechanism that lets a `ToolExecutor` address the selected connection owner. Do not duplicate request state in a second process.

Task channels become application observers. They no longer execute MCP calls merely because they received the same persisted PubSub interaction.

Project-context loading becomes normal application work after tool discovery:

- Check tool presence before calling `load_agent_instructions`.
- Check tool presence before calling `list_tree`.
- Use normal `tools/call` requests with complete per-request metadata.
- Require canonical structured content from project-context tools and delete legacy serialized-text parsing.
- Keep context-loading failures nonfatal where product behavior requires it.
- Deduplicate loading by task and context fingerprint.

Rename or remove `mcp_initialization_complete`; modern MCP has no initialization phase.

### Result Validation

Dispatch by `resultType` before method-specific parsing:

- `complete`: validate the exact expected result schema.
- `input_required`: reject as an unsupported optional result in the initial implementation.
- Unknown value: reject the peer response.
- Missing value: reject because Frontman is latest-only and has established a modern peer.

Do not answer malformed responses with a nonstandard `error` notification. Record a local protocol error, terminate the affected request, and apply the configured connection policy.

### Proof Gate

- No join-time MCP handshake remains.
- Every outbound request contains valid `_meta`.
- Every response is validated against the pending request kind.
- Randomized completion order preserves one-to-one correlation.
- Unknown, duplicate, malformed, and late responses cannot complete another request.
- Channel teardown leaves no pending entries or running browser work.

## Phase 6: Durable Execution Ownership

### Problem

Today, every task channel subscribed to a task can execute the same side-effecting tool call. Database uniqueness only deduplicates the persisted result after duplicate side effects have already happened.

### Work

Add atomic execution claims keyed by durable `tool_call_id`. First determine whether the existing durable tool-call row can hold and atomically transition the required ownership state. Add a separate claim table only if the existing row cannot provide correct transactional ownership and lease semantics.

Track:

- Tool call ID.
- Task ID.
- Owning MCP connection ID.
- Lease expiration.
- Resolution state.

Rules:

1. Claim atomically before sending `tools/call`.
2. Only the owner sends, retries, cancels, or accepts a response.
3. Duplicate channels and tabs observe but do not execute.
4. Claims renew only while the owner remains healthy.
5. Disconnect releases the claim or permits takeover after bounded expiry.
6. Resolution and claim completion are transactional with the canonical tool result.
7. Browser execution deduplicates the Frontman durable tool-call identifier.
8. Node-local Elixir Registry is not the ownership authority.

Exactly-once external side effects cannot be guaranteed across arbitrary network partitions unless each tool itself supports idempotency. The enforceable target is one active owner plus durable idempotency identifiers and explicit residual-risk handling.

### Proof Gate

- Two task channels produce one browser invocation.
- Two tabs produce one active owner.
- Competing Phoenix nodes produce one claim winner.
- Lease takeover is tested.
- Late results from former owners are ignored.
- Idempotent replay identifiers are preserved across reconnects.
- Non-idempotent takeover risk is documented and exposed to the user where necessary.

## Phase 7: Cancellation And Timeouts

### Work

Every sent request receives:

- A start timestamp.
- One absolute deadline.
- A cancellation mechanism.
- A pending-request owner.

Custom Phoenix transport cancellation uses `notifications/cancelled`.

Streamable HTTP cancellation closes the response stream and aborts fetch.

Timeout behavior:

- Timeout stops waiting and cancels actual work.
- ACP task cancellation cancels all pending MCP requests for that task.
- Disconnect aborts all browser-local and framework executions.
- Cancelled and completed request IDs remain in the smallest bounded recent-ID structure needed to classify duplicate and late responses safely.
- Late results are ignored and cannot persist a second terminal outcome.

### Proof Gate

- Cancellation before execution prevents side effects.
- Cancellation during execution stops cancellable work.
- Cancellation after completion is harmless.
- Timeout and completion races yield one terminal result.
- Disconnect and reconnect do not leak promises, fetches, readers, timers, or claims.
- Absolute timeout behavior is deterministic under fake time.

## Phase 8: Deferred MRTR And User Interaction Decision

Do not implement an MRTR state machine, request-state storage, or input capability in the initial migration. Initial client capabilities remain minimal. The browser must not request Roots, Sampling, or Elicitation unless Phoenix advertised the corresponding capability on that request.

Roots and Sampling are deprecated in `2026-07-28`; do not add new support.

### Question Tool Decision

The current question tool runs the user interface inside the browser MCP server. A cancellable long-running tool call is therefore protocol-valid and does not automatically require MRTR.

Two valid designs exist:

1. Keep `question` as a browser-local long-running tool with complete cancellation and reconnect behavior.
2. Advertise `elicitation.form`, return `resultType: "input_required"`, route the elicitation through Phoenix and ACP to the UI, then retry with a new request ID and exact `requestState`.

Initial decision: keep `question` as a browser-local long-running tool and make its current promise lifecycle cancellable, reconnect-safe, and unable to overwrite an unresolved resolver. Complete core conformance without MRTR.

Add Elicitation and MRTR only in a separate change with a concrete product caller, complete capability negotiation, opaque request-state handling, replay and expiry rules, bounded rounds, and its own conformance review.

### Proof Gate

- Undeclared capabilities are never requested.
- No MRTR state, capability, retry, or fallback exists in the initial runtime.
- Question cancellation, reconnect, redispatch, and concurrent-question tests leak no promises or resolver callbacks.

## Phase 9: Tool Content And Schema Safety

### Work

Define one canonical validated modern result at the persistence boundary. Preserve `resultType`, standard result metadata required for replay, `content`, arbitrary `structuredContent`, and `isError`; redact only explicitly sensitive vendor metadata. Use that representation through live executor delivery, historical reconstruction, ACP presentation, and LLM conversion instead of maintaining separate partial converters.

Persisted legacy ToolResults are a concrete compatibility boundary even though the wire protocol is latest-only. Add a one-time data migration that converts valid stored legacy results to the canonical internal shape by adding `resultType: "complete"` and preserving supported content. Make deployment fail visibly on malformed stored rows so they are remediated deliberately; do not keep a permanent runtime legacy parser or silent fallback.

Support all standard content types through that path.

Text:

- Preserve text exactly within documented size limits.

Images:

- Validate Base64.
- Validate MIME type.
- Enforce decoded byte and dimension limits where available.

Audio:

- Preserve protocol content.
- Convert to a clear textual representation for model runtimes without audio tool-result support.

Resource links:

- Preserve name and URI.
- Do not dereference automatically.

Embedded resources:

- Preserve URI, MIME type, text, or blob.
- Enforce byte limits.
- Never execute embedded content.

Structured content:

- Accept any JSON value.
- Validate against `outputSchema` when provided.
- Preserve the value without object-only narrowing.

Schema validation:

- Support JSON Schema 2020-12.
- Reject unsupported explicit dialects gracefully.
- Never fetch network `$ref` values by default.
- Bound composition depth, subschema count, and validation time.
- Exclude malformed tool definitions individually rather than poisoning the whole catalog where the specification requires exclusion.
- Use generic JSON Schema validation for untrusted remote catalogs in `frontman-client`.
- Use existing Sury schemas for Frontman-owned ReScript tool inputs and typed outputs in `frontman-core`; do not add a second general validator there without an untyped producer.

### Proof Gate

- Every official content variant passes.
- Invalid Base64, MIME, URI, schema, and oversized content fail deterministically without crashes.
- Array, primitive, and null structured content survive end to end.
- Network `$ref` tests prove no outbound request occurs.
- Existing valid persisted results migrate once and replay through the canonical path; malformed migration fixtures fail explicitly.

## Phase 10: Security And Authorization

### Framework MCP Servers

- Validate `Origin` on every request when present.
- Reject invalid origins with `403` before parsing or execution.
- Bind local development servers to loopback where possible.
- Remove wildcard CORS from `/mcp`.
- Echo only validated origins.
- Set `Vary: Origin`.
- Separate UI-route CORS from MCP endpoint policy.
- Rate-limit discovery, listing, and execution.
- Redact sensitive arguments and metadata from logs.
- Never use self-reported client information for authorization.

If remote framework MCP access is required, implement the MCP OAuth protected-resource flow as a separate complete feature. Do not invent an MCP-looking bearer-token subset.

### WordPress

Retain and test:

- Authenticated WordPress session.
- Required capability checks.
- Nonce validation on every MCP POST.
- Exact Origin validation.
- `cacheScope: "private"`.
- Authorization-specific cache keys.
- No filesystem tools unless explicitly and safely designed.

### Security Tests

- DNS rebinding and hostile Origin.
- Missing and malformed Origin.
- Unauthorized and insufficiently authorized callers.
- Wrong and replayed nonce.
- Header smuggling and CRLF injection.
- Base64 sentinel confusion.
- Host/header/body mismatch.
- Oversized and deeply nested JSON.
- Expensive JSON Schema composition.
- External `$ref` SSRF.
- Cross-user private-cache reuse.
- Tool argument leakage into logs.
- Request-state tampering and replay if MRTR state is generated.

### Proof Gate

- Applicable security `MUST` requirements have automated tests.
- Threat model receives independent review.
- No sensitive argument values appear in normal logs.
- Invalid requests have no observable tool side effect.

## Phase 11: Framework Adapter Cutover

### Next.js

- Route `/mcp` through generated middleware/proxy matchers.
- Update installer templates and automatic edits.
- Ensure no UI suffix routing rewrites `/mcp`.
- Propagate request disconnect to cancellation.

### Astro

- Handle `/mcp` before Astro page routing.
- Prevent trailing-slash and UI rewrite logic from changing `/mcp`.
- Use the consolidated Node/Web chassis to propagate stream closure and request abort.

### Vite

- Handle `/mcp` in the early middleware guard.
- Use the same consolidated Node/Web chassis as Astro for request abort/close, raw-byte response writes, reader cancellation, and no-buffer headers.
- Create Vite package tests because no `libs/frontman-vite/test/` suite currently exists.

### WordPress

- Route root and Playground-scoped `/mcp` correctly.
- Keep UI suffix routing separate.
- Return JSON for synchronous tools.
- Use SSE only when actual progress or streaming exists.
- Preserve WordPress authentication, capability, nonce, and Origin checks.

### Proof Gate

Run one shared black-box contract suite against:

- Next.js.
- Astro.
- Vite.
- WordPress.
- WordPress Playground scoped paths.

Every adapter must produce identical protocol behavior for the same request vector except for documented authentication and tool-catalog differences.

## Phase 12: Legacy Removal

Remove in the same breaking release:

```text
initialize
notifications/initialized
DRAFT-2025-v3
2025-11-25 runtime support
GET /frontman/tools
POST /frontman/tools/call
Relay protocol 1.0
custom bare SSE result/error events
required tools/call callId
connection-scoped MCP task context
parallel MCP20260728 runtime and generated schema exports
```

Delete obsolete schemas, generated files, tests, helpers, documentation, compatibility branches, installer fixtures, and shipped static browser-test bundles. Search every repository directory for legacy versions, methods, routes, event names, Relay symbols, and bare SSE event names rather than relying on this filename inventory.

Before completing removal, run repository-wide searches for at least:

- `DRAFT-2025-v3`, `2025-11-25`, `MCP20260728`, `initialize`, and `notifications/initialized` in MCP contexts.
- `/frontman/tools`, `/frontman/tools/call`, `FrontmanProtocol__Relay`, `FrontmanClient__Relay`, and Relay state variants.
- `event: result`, `event: error`, private SSE helpers, and generated bundles containing those strings.
- Wire-level `callId`, `visibleToAgent`, `executionMode`, and unnamespaced `access` serialization.
- Per-task `mcp:message` listeners, broad listener removal, and task-channel MCP execution routing.
- JSON body parsing outside the shared decoder, raising Base64 result decoding, non-empty-only content matches, and text/image-only converters.
- Wildcard CORS on tool-capable or source-location endpoints.
- Tool argument payload logging in normal and error paths.
- `/frontman`-only route guards, matcher templates, tracing exclusions, fixtures, and CI filters that must also know `/mcp`.

Each search result must be removed, migrated, or recorded as reviewed non-runtime data with a precise reason.

Do not ship a state in which one peer is modern and the other is initialization-era. Intermediate implementations may coexist only on the feature branch behind tests; deployment and package release are atomic.

Use a breaking changeset for every affected published package.

## Test And Verification Program

### Upstream Schema Tests

- Verify vendored checksums.
- Validate official examples.
- Validate every Frontman-produced request, result, error, and notification against its named upstream definition.
- Differentially generate locally accepted values and reject any value the upstream definition rejects.
- Keep these tests offline.

### Negative Protocol Matrix

Cover at minimum:

| Area | Cases |
| --- | --- |
| JSON-RPC | Wrong or missing version, invalid method, null/boolean/fractional/object/array ID, both result and error |
| Direction | Client response sent to server, server request sent to client |
| Metadata | Missing `_meta`, version, capabilities, or wrong metadata types |
| Versioning | Unknown and unsupported versions, exact `-32022` data |
| Headers | Missing, malformed, encoded, and mismatched standard/custom headers |
| Methods | Unknown methods and capability-gated unsupported methods |
| Tools | Missing name, unknown tool, invalid schema, malformed method params, and selected-tool input rejection with its distinct complete error result |
| Results | Missing/unknown `resultType`, malformed content, invalid cache fields |
| Correlation | Unknown ID, duplicate response, cancelled response, stale owner response |
| Extensions | Unknown valid extension, malformed negotiated extension, reserved-prefix misuse |
| Limits | Oversized body, metadata, catalog, content, schema depth, pagination loop |

Every negative case asserts:

- Exact HTTP status where applicable.
- Exact JSON-RPC error code and required data.
- No tool execution.
- No leaked pending request, timer, stream, claim, or promise.

### Property Tests

Use deterministic seeds and persisted replay paths.

Properties:

- Legal IDs produce exactly one response with the identical ID.
- Arbitrary JSON arguments round-trip unchanged.
- Arbitrary legal vendor metadata round-trips unchanged.
- Arbitrary structured JSON round-trips unchanged.
- Removing a required field causes rejection.
- Replacing typed fields with other JSON classes causes rejection unless permitted.
- Valid serialization never creates `undefined`, NaN, infinity, or non-JSON values.
- Arbitrary parsed input never throws outside the handler.
- Tool execution occurs only after full request validation.
- Concurrent request completion is a one-to-one permutation by ID.

Run at least 1,000 deterministic cases in pull requests and 10,000 in scheduled CI.

### Cross-Language Contract Tests

Create semantic fixtures for:

- Discovery.
- Tool listing with the initial single-page result.
- Tool calls with and without arguments.
- Every content block.
- Arbitrary structured content.
- Tool execution errors.
- Protocol errors.
- Unsupported versions.
- String and numeric IDs.
- Cancellation.

ReScript and Elixir independently emit envelopes. Compare parsed JSON structurally and validate both against the upstream schema.

### Concurrency And Fault Tests

- 100 simultaneous calls with randomized completion order.
- Multiple task channels.
- Multiple browser tabs.
- Multiple Phoenix nodes.
- Disconnect during every request stage.
- Cancellation before, during, and after execution.
- Completion racing timeout.
- Lease expiry and takeover.
- Duplicate and late terminal responses.
- Repeated pagination cursors.
- Broken SSE at every byte boundary.
- Proxy buffering and delayed chunks.

### End-To-End Tests

Exercise the full path:

```text
LLM tool call
-> existing Phoenix TasksChannel connection owner
-> browser MCP server
-> browser Streamable HTTP client
-> framework MCP server
-> tool execution
-> validated result
-> persistence
-> ACP update
-> agent continuation
```

Cover:

- Browser-local read tool.
- Browser-local write or interaction tool.
- Framework read tool.
- Framework write tool.
- Tool execution error.
- Protocol error.
- Empty, text, image, audio, resource-link, embedded-resource, and structured results.
- Object, array, string, number, boolean, and null structured content through persistence, ACP, history replay, and model conversion.
- Cancellation.
- Reconnect and owned replay.

### Official Conformance Runner

Pin an exact official conformance-runner version or immutable source commit that supports `2026-07-28`.

Do not fetch or update it during CI.

Do not accept an expected-failure baseline for the final gate.

The final result must contain:

- Zero failures.
- Zero expected failures.
- Zero skipped applicable cases.
- A recorded runner version and checksum.

The runner is one proof source, not the only source. Schema validation cannot prove timing, cancellation, security, side-effect ownership, or application correctness.

## CI Gates

Add one package-local protocol verification target and one root aggregate target:

```text
make -C libs/frontman-protocol mcp-verify
make mcp-verify
```

The package target owns schema, fixture, differential, and property checks. Root `make mcp-verify` composes existing package test targets, adapter black-box tests, custom transport tests, Streamable HTTP tests, concurrency tests, the pinned conformance runner, relevant E2E tests, the tracked-authored-source zero-comment scan, and generated-diff checks. Add another public Make target only when it has distinct setup or independent human callers.

Pull-request CI runs:

- Schema checksum and official examples.
- Shared protocol build and generated-schema check.
- ReScript and Elixir contract tests.
- Negative matrix.
- Property tests with fixed seed.
- Browser custom transport tests.
- Streamable HTTP tests.
- Server and client unit tests.
- Adapter contract tests.
- Relevant end-to-end tests.
- Tracked-authored-source zero-comment verification.
- Formatting, static analysis, and existing precommit suites.

Correct `.github/workflows/e2e.yml` path filters. Remove the nonexistent `adapters/**` assumption and include `libs/frontman-core/**`, `libs/frontman-protocol/**`, `libs/frontman-nextjs/**`, `libs/frontman-astro/**`, `libs/frontman-vite/**`, `libs/frontman-wordpress/**`, checked-in integration fixtures, generated browser-test assets, root MCP Makefile changes, and shared test harness changes.

Scheduled CI runs:

- Larger property-test counts.
- Multi-node concurrency.
- Soak tests.
- Fault injection.
- Full adapter and compatibility matrices.

## Documentation Deliverables

Create and maintain:

- MCP custom Phoenix transport specification.
- Frontman MCP extension specification.
- Streamable HTTP endpoint documentation.
- Origin and authentication configuration guide.
- Capability support matrix.
- Implementation limits document.
- Normative traceability matrix.
- Threat model.
- Schema and conformance artifact refresh procedure.
- Migration guide from the removed private relay.
- Troubleshooting guide with protocol-safe diagnostics.

Update architecture and marketing documentation so it distinguishes:

- Phoenix custom MCP transport.
- Browser MCP server.
- Browser Streamable HTTP MCP client.
- Framework Streamable HTTP MCP server.
- ACP application/session protocol.

Do not describe a private relay as MCP.

## Review Process

Require separate reviews for:

1. Wire contract and schema fidelity.
2. Streamable HTTP transport and status/header behavior.
3. Custom Phoenix transport and existing `TasksChannel` connection-owner lifecycle.
4. Concurrency, claims, replay, and side effects.
5. Security and authorization.
6. Question cancellation and proof that deferred MRTR is absent from advertised capabilities and runtime state.
7. Cross-language persistence and content conversion.
8. Documentation and normative traceability.

At least one final reviewer should work from the specification and traceability matrix rather than from the implementation design.

## Release Acceptance Criteria

The implementation must not be labeled MCP `2026-07-28` conformant until all criteria are true:

1. Every applicable normative requirement has a code reference and test reference.
2. Every emitted and accepted wire message validates against the pinned official schema.
3. All official examples pass.
4. Every negative test returns the exact required error and causes no side effect.
5. ReScript and Elixir contract fixtures are structurally identical.
6. All advertised capabilities are fully implemented.
7. No unsupported capability is advertised or silently approximated.
8. The custom Phoenix transport is documented and passes its contract tests.
9. Streamable HTTP passes black-box transport tests.
10. The official conformance runner has zero failures and zero accepted exceptions.
11. Multi-client, multi-tab, reconnect, timeout, cancellation, and lease races pass.
12. Security tests and independent threat-model review pass.
13. Next.js, Astro, Vite, WordPress, and Playground end-to-end tests pass.
14. Full existing package and server regression suites pass.
15. Generated source and schemas are clean after regeneration.
16. Breaking changesets and migration documentation are complete.
17. Legacy runtime paths and protocol declarations are removed.
18. No parallel MCP contract, broker process, duplicated Node/Web bridge, legacy project-context parser, or compatibility fallback remains.
19. The source-aware zero-comment gate passes on tracked authored source files; only approved platform-required executable directives remain, and generated artifacts and build outputs are outside the gate.

## Residual Risks To Record

Even after all gates pass, record these residual risks explicitly:

- Official conformance tooling may itself contain defects or incomplete cases.
- JSON Schema cannot validate prose-only timing and lifecycle requirements.
- Network partitions can make exactly-once non-idempotent side effects impossible without tool-level idempotency.
- Browser scheduling and proxy behavior can differ from deterministic tests.
- Cross-language implementations can share the same misunderstanding; independent upstream validation remains mandatory.
- New upstream errata may require a deliberate schema refresh and review.
- Third-party framework and WordPress environments may alter headers, buffering, routing, or connection-close behavior.

## Recommended Implementation Order

1. Commit and merge the accepted standalone tracked-authored-source zero-comment cleanup from `.worktrees/chore/zero-comment-prerequisite` before protocol implementation.
2. Freeze decisions and complete the normative traceability matrix.
3. Pin the upstream TypeScript schema, generated JSON Schema, examples, license, and conformance tooling.
4. Replace the existing shared MCP wire contract in place, consolidate common JSON-RPC/content types, and delete the parallel modern contract.
5. Define and test one canonical persisted tool-result representation across live, historical, ACP, and model paths.
6. Consolidate the duplicated Vite/Astro Node/Web bridge into shared chassis.
7. Implement and prove the synchronous framework `/mcp` server in `frontman-core`, reusing existing registry, Sury schemas, and execution helpers.
8. Implement and prove the reusable browser Streamable HTTP client in `frontman-client`.
9. Wire `/mcp` through Vite, Astro, Next.js, WordPress, installers, checked-in fixtures, scoped paths, logging exclusions, and direct Relay consumers.
10. Implement the modern browser MCP server on the custom Phoenix transport.
11. Move connection-wide Phoenix MCP ownership into the existing `TasksChannel` and remove per-task-channel execution routing.
12. Implement the smallest correct durable execution claim, cancellation, deadline, and replay behavior using existing persistence where possible.
13. Complete content handling, remote schema safety, Origin policy, security, and logging cleanup across every sibling path.
14. Correct CI path ownership and run shared adapter, concurrency, security, and full end-to-end suites.
15. Remove every legacy protocol, Relay, generated, fixture, static-asset, test, and documentation artifact.
16. Run the complete acceptance gate and independent final review.
17. Release as an explicitly breaking, latest-only protocol migration.

## Definition Of Done

Frontman is done with the migration when a reviewer can start from the official MCP `2026-07-28` specification, follow every applicable normative requirement through the traceability matrix to implementation and tests, run all checks offline, run the pinned official conformance suite with no exceptions, and observe no legacy MCP, private relay, parallel contract, duplicate transport chassis, unsupported optional runtime machinery, compatibility fallback, or prohibited comment remaining in the repository or shipped system.
