# MCP Implementation Limits

These limits are part of Frontman's MCP `2026-07-28` contract. A maximum is
inclusive: a value exactly at the limit is accepted when it is otherwise valid,
and the first unit over the limit is rejected. Limits are measured independently;
passing one limit does not bypass another.

No limit failure may execute a tool, replace a valid cache with partial data,
truncate protocol data, or log rejected payload content. Error details identify
only the limit and configured maximum.

## Numeric Request IDs

Numeric JSON-RPC IDs are limited to JavaScript safe integers from
`-9,007,199,254,740,991` through `9,007,199,254,740,991`, inclusive. String IDs
have no numeric interpretation and are unaffected by this limit. MCP permits any
JSON integer, but Frontman's JavaScript boundaries reject values outside this
range because distinct unsafe integers can decode to the same `number` and cannot
be correlated losslessly. This follows the ECMAScript
[`Number.isSafeInteger`](https://tc39.es/ecma262/#sec-number.issafeinteger)
domain.

| At limit | Over limit | Owner | Proof test |
| --- | --- | --- | --- |
| Preserve the exact numeric type and value through request, cancellation, response, and serialization boundaries. | Reject the message before dispatch, correlation, cancellation, persistence, or trusting the unsafe ID. | Shared JSON-RPC ID schema and every JavaScript transport consumer | Validate both inclusive bounds and the first integers outside them through runtime and generated schemas; record that the unrestricted upstream integer schema accepts the rejected values. |

## HTTP Body Bytes

| Direction | Maximum | Measurement | At limit | Over limit | Owner | Proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Incoming `/mcp` POST body | `2,097,152` bytes (2 MiB) | Raw bytes as received, before UTF-8 or JSON decoding. A valid `Content-Length` is checked before reading and the streaming reader independently counts actual bytes. | Continue to UTF-8, JSON, and protocol validation. | Return HTTP `413 Payload Too Large` with an empty body. Do not parse JSON, trust an ID, execute a tool, or persist data. | Shared Streamable HTTP request handler and each framework adapter, including the WordPress router | Send valid requests whose raw bodies are exactly `2,097,152` and `2,097,153` bytes; repeat with matching, missing, understated, and overstated `Content-Length`; assert no side effect on every rejection. |
| Nonterminal chunks in one incoming `/mcp` POST body | `4,096` chunks | Count every nonterminal reader result, including zero-byte chunks, before copying or decoding it. | Continue reading subject to byte and time limits. | Cancel the reader and return HTTP `400` with a fixed ID-less JSON-RPC `-32700 Parse error` before trusting an ID, executing a tool, or persisting data. | `FrontmanCore__MCP__BodyReader`, `FrontmanCore__MCP__HttpRequest`, shared Node/Web chassis, and cancellation-aware tool context | Stream exactly `4,096` and `4,097` zero-byte chunks; assert deterministic rejection over the limit, reader cancellation and lock release, exact response mapping, and no parsing or side effect. |
| Streamable HTTP response consumed by the browser | `12,582,912` bytes (12 MiB) | Raw bytes read from an `application/json` body or cumulatively from an SSE response, including SSE framing. Count incrementally before concatenation or JSON decoding. | Continue response validation. | Abort the fetch and stream reader immediately, discard the entire response, and fail the originating request with local transport reason `response_body_limit_exceeded`. Never use or cache a partial result. | Browser Streamable HTTP client | Serve JSON and byte-split SSE responses exactly at and one byte over the maximum; assert reader cancellation, one terminal failure, no partial catalog/result, and no leaked fetch or reader. |

One Phoenix `mcp:message` payload is also limited to `2,097,152` UTF-8 bytes.
WordPress validates Origin, application authentication, media, and declared size before opening `php://input`, then reads at most `2,097,153` bytes to enforce the same actual-byte boundary. PHP exposes a buffered request stream rather than the shared Web reader, so the 4,096-chunk rule and JavaScript adapter idle/absolute timers do not apply; the hosting web server owns request-read deadlines.
Real WordPress and WordPress Playground black-box profiles therefore share routing, Origin, authentication, preflight, media, discovery, catalog, call, malformed-input, and protocol-error vectors with the JavaScript adapters. They explicitly do not claim the Node/Web chassis chunk limit, response-stream commitment, absolute deadline, or PHP-side disconnect cancellation. Playground uses WordPress session cookies and a plugin nonce at its scoped site URL; the JavaScript adapters use configured bearer authorization at root `/mcp`.
The custom transport closes an oversized WebSocket frame with close code `1009`.
If an adapter has already decoded an oversized event, the Phoenix connection owner
cancels affected work and closes the connection without accepting any request ID
from that event.

## JSON Nesting Depth

The maximum JSON nesting depth is `64`. A top-level object or array has depth 1;
entering an object or array value adds one. Scalars do not add depth. Depth is
measured over the complete JSON value, including `_meta`, schemas, tool arguments,
structured content, and embedded resource fields.

| At limit | Over limit | Owner | Proof test |
| --- | --- | --- | --- |
| A valid value at depth `64` proceeds to schema validation. | HTTP input returns HTTP `400` with a fixed ID-less JSON-RPC `-32700 Parse error`; the HTTP boundary omits `id` because no complete JSON value exists. A Phoenix frame is rejected before dispatch; it may receive `-32700` only if its ID was recovered independently without traversing the over-depth value, otherwise the connection is closed. No side effect occurs. | Shared bounded untyped JSON decoder used by the framework HTTP boundary, browser HTTP client, and Phoenix custom transport | Generate equivalent object and array fixtures at depths `64` and `65` for each boundary; assert deterministic rejection, no stack overflow, and no handler dispatch at `65`. |

## Metadata Bytes And Keys

Each `_meta` object has both limits below. Required MCP keys count toward the key
limit. Nested objects are included in the byte measurement and governed by JSON
depth, but only immediate members of that `_meta` object count as metadata keys.

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Metadata bytes | `16,384` bytes | UTF-8 byte length of the compact JSON encoding of the complete `_meta` object. | Continue metadata schema and reserved-key validation. | Reject an HTTP request with HTTP `400` and JSON-RPC `-32602 Invalid params`; reject a Phoenix request with `-32602`. Reject an oversized response as a malformed peer response before persistence. | Shared MCP contract validator, browser HTTP client, and Phoenix connection owner | Build valid metadata encodings of exactly `16,384` and `16,385` bytes on requests and responses; assert round-trip preservation at the limit and rejection without dispatch or persistence over it. |
| Immediate metadata keys | `64` | Number of own keys directly in each `_meta` object after JSON parsing. | Continue validation. | Apply the same request or response behavior as the metadata byte limit. | Shared MCP contract validator | Validate `_meta` with exactly `64` and `65` valid keys, including required MCP keys, on every accepted message shape. |

## Tool Catalog

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Assembled remote tools | `256` | Number of remote tools accumulated across every page before invalid individual definitions are excluded. | Continue individual validation and publish the accepted complete catalog. | Abort assembly before publishing or replacing a prior cache. | `FrontmanClient__MCP__Client` Streamable HTTP owner | Real-server exact `256/257` vectors prove acceptance and rejection without caching. |
| One tool definition | `65,536` bytes (64 KiB) | UTF-8 byte length of the compact JSON encoding of one complete tool definition. | Continue schema and annotation validation. | Exclude only that tool, warn with tool name and categorical reason, and continue validating valid siblings. Never log the definition. | Browser remote tool-definition validator; Frontman-owned registries enforce the same limit at build/test time | Place definitions of exactly `65,536` and `65,537` bytes between valid siblings; assert acceptance at the limit, individual exclusion over it, and stable sibling order. |
| Complete catalog definitions | `1,048,576` bytes (1 MiB) | Sum of compact UTF-8 definition bytes for all accepted tools in the assembled catalog. | Publish and cache the complete validated catalog. | Abort catalog assembly with `catalog_bytes_limit_exceeded`; do not publish, truncate, or cache the partial catalog. | Browser Streamable HTTP client and browser MCP server catalog owner | Assemble accepted definitions totaling exactly `1,048,576` and `1,048,577` bytes across page boundaries; assert all-or-nothing publication. |

`FrontmanCore__ToolRegistry` applies the same inclusive limits to every owned
registry composition operation. It validates visible and hidden definitions,
requires unique case-sensitive names matching `[A-Za-z0-9_.-]{1,128}`, and rejects
the complete proposed registry atomically. `FrontmanCore__ToolRegistry.test.res`
proves `256/257`, duplicate and invalid names, exact `65,536/65,537` definition
bytes, and exact `1,048,576/1,114,112` aggregate bytes.

The Phoenix connection owner also rejects a `tools/list` result containing more
than `256` tools before converting or publishing any catalog entry.

The WordPress registry enforces the same inclusive `256` tool, `65,536` byte
per-definition, and `1,048,576` aggregate-definition limits while tools are
registered. It rejects invalid or duplicate names before insertion and never
publishes a partial over-limit definition. Tool names are case-sensitive, one
through 128 ASCII letters, digits, underscores, hyphens, or dots.

## Project Context

Phoenix project-context loading has these inclusive limits: `256` tracked tasks,
`64` rules per result, `4,096` UTF-8 bytes per rule path, `65,536` UTF-8 bytes per
rule content value, `262,144` UTF-8 bytes for the structure tree, `64` workspaces,
and `4,096` UTF-8 bytes for each workspace name and path. The first unit over any
limit rejects that loading step without truncation or fatal channel failure. The
task remains retryable through a later `load_task` request.

## Pagination

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Pages | `32` | The initial `tools/list` response is page 1. Every response consumed increments the count once. | Accept page 32 only if it has no `nextCursor`; complete catalog assembly. | If page 32 has `nextCursor`, do not request page 33 and do not publish partial data. | `FrontmanClient__MCP__Client` Streamable HTTP owner | Real-server exact `32/33` vectors prove page-32 acceptance and no page-33 request or cache publication. |
| Cursor bytes | `4,096` bytes | UTF-8 byte length of each present cursor; empty string measures zero. | Send the cursor unchanged. | Abort listing with `pagination_cursor_limit_exceeded` before sending it. | Browser Streamable HTTP client | Exercise valid cursors of `0`, `4,096`, and `4,097` bytes and assert exact opaque preservation for accepted values. |

Cursor values are opaque. The browser does not compare, parse, modify, or infer loop
meaning from them; repeated and empty-string cursors are forwarded unchanged. The
independent 32-page bound prevents unbounded pagination. If a continuation request
receives `-32602`, the client discards every page from that operation and restarts once
from the beginning. A second invalid-cursor response fails without publication or retry.

Discovery expiry is computed from receipt of the discovery result. Each tools page expiry
is computed from that page's receipt, and the assembled catalog uses the earliest expiry
across discovery and all pages. Network time before receipt never consumes the advertised
TTL; no partial page set is cached.

## Schema Safety

Limits apply separately to each `inputSchema` and `outputSchema`. Network,
file, data, and cross-document `$ref` values are never fetched. Internal fragment
references may resolve only inside the same bounded schema document.

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Schema structural depth | `32` | Maximum JSON nesting traversed from the schema root before validator compilation. This is distinct from instance JSON depth. | Compile through the bounded validator. | Reject the affected owned definition or exclude the affected remote definition. | Browser `FrontmanClient__MCP__RemoteSchema`, framework `FrontmanCore__MCP__JsonSchema`, and server `FrontmanServer.JSONSchema` | Framework exact `32/33` and existing browser/server vectors pass. |
| Schema container nodes | `1,024` | Every object and array in the schema JSON document, including keyword maps and annotation values. Local reference strings do not cause another traversal. | Compile in an isolated validator. | Reject the affected owned definition or exclude the affected remote definition. | Browser, framework, and server JSON Schema validators | Framework and existing remote validators prove exact `1,024/1,025` boundaries. |
| Compile or instance validation duration | `100` milliseconds | Monotonic wall-clock time for one schema compilation or one instance-validation operation in an interruptible Worker or equivalent isolated process. | A result completed at or before `100 ms` is accepted. | Terminate the validation worker or process. Catalog compilation timeout rejects that owned definition or excludes that remote tool. Input-validation timeout prevents request transmission. Output-validation timeout returns one canonical tool error and never retries execution. | Browser `FrontmanClient__MCP__RemoteSchema` Worker, framework `mcp-json-schema-worker.mjs`, and server `FrontmanServer.JSONSchema` isolated process | Framework tool calls use a fresh ready-signalled worker and terminate it at the boundary; existing browser/server timeout probes cover their owners. |

Framework output instances additionally permit at most `64` container depth,
`65,536` object/array nodes, and `2,097,152` compact UTF-8 JSON bytes. Exact
depth `64/65`, node `65,536/65,537`, and byte `2,097,152/2,097,153` vectors are in
`FrontmanCore__MCP__JsonSchema.test.res`. Framework validation defaults to JSON
Schema 2020-12, accepts only that explicit dialect, permits only same-document
fragment `$ref` and `$dynamicRef` values, supplies no external loader, and rejects
HTTP, loopback, file, data, and cross-document references before compilation.

WordPress-owned input schemas use a registration-validated JSON Schema 2020-12
profile. The supported validation keywords are `type`, `properties`, `required`,
`additionalProperties` as a boolean, `items`, `enum` over primitive typed values,
and `minProperties`; `description` and `default` are annotations. An absent type
is accepted only for an unconstrained nested value, while every tool root must
have `type: "object"`. An absent `additionalProperties` means `true`. The optional
`$schema` value must be the 2020-12 URI. Every other vocabulary, dialect, malformed
keyword value, and array or object enum is rejected when the owned tool is
registered. The runtime validator and sanitizer consume that same accepted
profile, so no advertised constraint is silently ignored.

## WordPress Request Rate

Authenticated WordPress `server/discover`, `tools/list`, and `tools/call` requests
share an inclusive fixed-window budget of `256` requests per `60` seconds for each
`wordpress:{blog ID}:user:{user ID}` authorization principal. The non-autoloaded
option key contains only a SHA-256 digest of that principal. Compare-and-swap
updates prevent concurrent workers from oversubscribing the boundary and fail
closed after eight storage-contention attempts. Request 256 is accepted, request
257 receives an empty HTTP `429` with a deterministic `Retry-After`, and a request
at the exact window-expiry second starts a new budget. Distinct authorized users
and sites do not share budgets. Missing or malformed principals and malformed or
unpersistable limiter state fail closed with no tool execution; preflight remains
Origin-only and does not consume a budget.

## JavaScript Framework Request Rate

Configured JavaScript framework `/mcp` endpoints share an inclusive fixed-window
budget of `256` authenticated POST requests per `60,000` milliseconds for each
authorization-specific principal. The exact `Authorization` header is the
in-memory key when present; Frontman's accepted HttpOnly browser credential is
used next, and the already authorized canonical Origin is the conservative
fallback key. Keys are never emitted or logged. Preflight and
requests rejected by Origin or authorization do not consume a budget. All
authenticated POST requests consume it before body reading, so malformed requests
cannot evade accounting.

Each security policy retains at most `4,096` principal windows and accepts keys of
at most `8,192` UTF-8 bytes. Expired windows are removed before capacity rejection.
Request 256 is accepted, request 257 receives empty HTTP `429` with deterministic
`Retry-After`, and a request at exact expiry starts a new window. Invalid clock
input, an oversized key, or capacity with no expired entry fails closed as empty
HTTP `503`. `FrontmanCore__MCP__RateLimiter.test.res` proves exact count, expiry,
principal isolation, key and principal capacity, and cleanup. The active endpoint
test proves rejection before parsing/execution, no side effect, alternate-principal
isolation, and no payload in the response.

## Browser Tool Invocation Rate

One browser custom-Phoenix MCP server accepts at most `256` tool invocations in one
fixed `60,000` millisecond window. The budget is per browser server instance and covers
local and framework-backed calls before consent or execution. Invocation 256 is accepted;
invocation 257 returns a complete tool error without dispatch. At the exact window-expiry
millisecond a new window begins. This time-window budget is independent of the existing
limit of 256 underlying active durable executions.

## Custom Header Representation

The Node adapters capture the alternating name/value `rawHeaders` array before constructing
Web `Headers` and pass its typed representation into the route-independent framework
validator. Recognized names are matched case-insensitively against that physical list. Zero
physical fields means omission, one field supplies the exact value, and two or more fields
produce `HeaderMismatch` before complete argument validation or execution. A malformed odd
Node array crashes as an adapter invariant. Unrecognized `Mcp-Param-*` fields remain ignored
by the endpoint server.

Web `Headers` still combines duplicate fields, so annotated validation crashes if raw
physical evidence is unavailable rather than trusting a folded value. One physical field
containing commas remains one value and is never split. Configured JavaScript framework
adapters now route exact `/mcp` and pass the chassis abort signal into selected tool execution.

Vite, Astro, and the route-independent Next.js Node API adapter use one shared Node/Web
chassis. It captures `IncomingMessage.rawHeaders`, requires an unconsumed Node stream before
body adaptation, permits Origin and adapter authorization before `Readable.toWeb`, and streams
exact response bytes with backpressure. Request abort and response close abort the matching
signal, cancel an acquired response reader, suppress late responses, and remove lifecycle
listeners. Next.js Proxy and App Route Handler requests expose only folded Web `Headers` and
are not physical evidence. The installer generates a Pages API Route with
`config.api.bodyParser: false`; if prior parsing actually consumes the stream, the adapter
crashes rather than trusting already-consumed input. App and Pages routers may coexist, and
the generated exact rewrite exposes public `/mcp` through that Node route.

Recognized integer values use integral JSON-number syntax. Numerically equivalent forms,
including zero-only fractional suffixes and exponent notation, compare equal only when the
text denotes an exact mathematical integer in the inclusive IEEE-754 safe range. Lexically
fractional values that round to an integer in JavaScript are rejected before conversion.
Malformed annotations on Frontman-owned generated schemas crash as server defects; they are
not converted into an incoming `HeaderMismatch` response.

## Tool Results And Media

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Result content blocks | `64` | Number of entries in `CallToolResult.content`, including every standard block type. Empty content is valid. | Validate and preserve all 64 blocks. | Reject the entire peer result before persistence. Complete the durable tool call once with a small canonical protocol-error result. Never truncate blocks. | Canonical result validator at the persistence boundary | Pass results containing `0`, `64`, and `65` valid mixed content blocks through live delivery, persistence, ACP, history replay, and model conversion. |
| Decoded media per block | `8,388,608` bytes (8 MiB) | Decoded bytes for image data, audio data, or an embedded blob. Canonical Base64 encoded length is checked before one bounded decode. | Preserve the valid block subject to the aggregate limit. | Reject before decoding an over-limit value, reject the entire result before persistence, and resolve once with the canonical protocol-error result. Invalid Base64 follows the same path. | Canonical result validator | Test valid Base64 decoding to exactly `8,388,608` and `8,388,609` bytes for image, audio, and embedded blob blocks, plus invalid Base64 near the boundary. |
| Decoded media per result | `8,388,608` bytes (8 MiB) | Sum of decoded image, audio, and embedded-blob bytes across all content blocks. Text and resource links do not consume this budget. | Preserve the complete result. | Reject the complete result before persistence; never preserve only the blocks that fit. | Canonical result validator | Split exactly-at-limit and over-limit media across multiple block types and assert all-or-nothing persistence. |
| Embedded text resource | `8,388,608` UTF-8 bytes (8 MiB) | Byte size of one embedded resource `text` value. | Preserve the complete resource. | Reject the complete result before persistence. | Canonical result validator | Exact `8,388,608/8,388,609` UTF-8 byte vectors pass. |
| Image dimensions | `7,680` pixels per axis | Width and height parsed from JPEG, PNG, GIF, or WebP headers when available. | Preserve an image with either axis at `7,680`. | Reject an image when either parsed axis is `7,681` or greater. Unknown formats remain governed by MIME and byte limits. | Canonical result validator using `FrontmanServer.Image` | PNG exact `7,680/7,681` vectors pass; the shared parser retains focused JPEG, PNG, GIF, and WebP coverage. |

## Request Timeouts

Every request records a monotonic start time, one immutable absolute deadline,
one idle timer where applicable, a pending owner, and a cancellation mechanism.

| Timeout | Value | Measurement | At limit | Over limit | Owner | Proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Idle | `60,000` milliseconds | Inactivity while receiving a request body or after HTTP response headers establish a JSON/SSE response stream. Valid received bytes, including SSE comment bytes, reset idle time. Waiting for initial response headers is governed by the absolute deadline, not a separate idle deadline. | Activity at exactly `60,000 ms` resets the timer. | Abort body/stream/fetch and cancellable work, remove pending state once, mark the ID recent, and return one timeout outcome. The route-independent framework input boundary returns empty HTTP `408`; later bytes or responses are ignored. | Framework body input: `FrontmanCore__MCP__BodyReader` and `FrontmanCore__MCP__HttpRequest`; shared Node/Web chassis owns disconnect cancellation; browser Streamable HTTP client owns outgoing response lifecycle | Framework and browser-client fake-time vectors cover `60,000` and `60,001` milliseconds, zero-byte chunks, completion and late-byte races, nonsettling cancellation, lock release, and timer cleanup. The framework boundary additionally proves exact 408 mapping. |
| Absolute | `600,000` milliseconds (10 minutes) | Elapsed monotonic time from immediately before active framework request processing or browser request send. It never resets for progress, keepalive, retry, or activity. | A terminal response committed at the deadline wins atomically. | The active framework chassis aborts its execution signal and returns one empty HTTP `408`; browser/Phoenix owners remove pending state, mark the ID recent, and propagate cancellation through their ownership state. A later completion cannot write or persist. | Active framework request: `FrontmanCore__NodeWebChassis`; outgoing browser request: issuing browser transport and Phoenix `TasksChannel` connection owner | Framework, browser, and Phoenix exact-boundary, cancellation, disconnect, late-result, and durable lease/deadline suites pass. |

BlueHotDog explicitly accepted the fixed timeout policy. Frontman does not expose
per-request timeout configuration; this is a reviewed SHOULD deviation, not an
unimplemented MUST. BlueHotDog also accepted terminal cancellation visibility
without a separate transient cancellation-request UI state. Framework listener
binding and local-process sandboxing remain embedding-host responsibilities:
local hosts must choose loopback or an equivalently protected listener and apply
least privilege and platform sandboxing appropriate to their deployment.

## Late-Response Tracking

Each Phoenix MCP connection retains at most `4,096` terminal request IDs for
`900,000` milliseconds (15 minutes). Each entry contains ID with exact JSON type,
request kind/method, terminal reason, terminal time, and former execution owner.
Expired entries are removed first; capacity then evicts the oldest entry. Eviction
does not reject a new request and IDs are never reused within a connection.

| At limit | Over limit | Owner | Proof test |
| --- | --- | --- | --- |
| Retain all `4,096` unexpired entries. A response for one is classified as duplicate or late, ignored, and counted. | Inserting entry `4,097` evicts exactly the oldest retained entry. Any response without a matching pending entry remains unable to complete any request, whether it is retained-recent or unknown. | Existing Phoenix `TasksChannel` connection owner | Under fake time, fill `4,096`, add one, expire entries at `900,000`/`900,001 ms`, and send late, duplicate, unknown, numeric-ID, and string-ID responses in randomized order; assert no cross-completion or second persistence. |

## Durable Ownership Lease

The execution claim lease is `60,000` milliseconds and is renewed every
`20,000` milliseconds while the owning MCP connection is healthy. Lease timestamps
use database time. Acquisition, renewal, expiry takeover, and terminal completion
use atomic compare-and-set operations keyed by durable `tool_call_id`.

| At limit | Over limit | Owner | Proof test |
| --- | --- | --- | --- |
| Through the exact expiration instant, only the current owner may send, retry, cancel, or accept a response. A renewal committed at the instant extends the lease. | After expiration, exactly one contender may atomically claim. The former owner may no longer renew or resolve, and its late result is ignored. Graceful disconnect atomically records a terminal cancellation instead of releasing started non-idempotent work for replay. | Tasks persistence as durable claim authority; Phoenix connection owner as lease holder | Database-controlled tests prove exact active/expired boundaries, one winner across independent PostgreSQL connections, renewal, graceful terminal cancellation, former-owner rejection, dispatch ambiguity, and transactional result completion. Accepted single-node crash-boundary proof includes fresh-BEAM recovery and post-commit/pre-notification death; distributed-node acceptance remains explicitly out of scope. |

Lease takeover does not imply automatic execution replay. If the previous owner may
have begun a non-idempotent side effect and no terminal result proves its outcome,
Frontman marks the call as requiring explicit user resolution. It must not resend the
tool call automatically. Automatic owned retry is allowed only when no execution began
or when the tool has a verified idempotency guarantee bound to the preserved durable
tool-call identifier.

## Browser Durable Execution Tracking

One browser MCP handler retains at most `256` underlying active durable executions,
including cancelled executions whose tools have not settled. Multiple identical requests
with new JSON-RPC IDs join one execution by exact task and durable tool-call identity.
Changed replays are rejected using canonical structural request comparison.

The handler admits at most `4,096` distinct durable execution identities and
`1,048,576` aggregate UTF-8 bytes of durable keys plus canonical request fingerprints
during its lifetime. At either capacity, every previously unseen identity is rejected
until detach; no tombstone is evicted in a way that could permit re-execution. Up to
`256` completed results and a separate `1,048,576` aggregate compact UTF-8 result bytes
are retained for response replay. Result eviction or an individually oversized result
preserves a tombstone and therefore rejects rather than re-executes a later replay.
Detach aborts active execution, clears handler-owned state, and relies on the PostgreSQL
claim generation as the durable authority across connections and reloads.

## Browser-Facing Origin Gate

Although Origin is a security policy rather than a Phase 0 numeric limit, it is a
mandatory precondition for every browser-facing `/mcp` request. The endpoint accepts
only an `Origin` value that exactly matches a configured allowlist entry after standard
URL parsing, including scheme, host, and effective port.

Missing `Origin`, `Origin: null`, malformed values, multiple values, wildcard/suffix
matches, and otherwise unlisted origins return HTTP `403 Forbidden` with an empty body.
Origin validation runs before authentication, body reading, JSON parsing, or execution.
Rejected responses do not include `Access-Control-Allow-Origin`. Accepted cross-origin
responses echo only the validated origin and include `Vary: Origin`; wildcard MCP CORS
is forbidden.

The Origin proof suite covers exact allowed origins, scheme/host/port
changes, missing, `null`, malformed, duplicate, userinfo, trailing-dot, encoded-host, and
hostile DNS-rebinding values and asserts zero tool side effects on every rejection. The
active endpoint additionally proves Origin-only preflight routing and one authorization
decision for each non-preflight request.

The route-independent `FrontmanCore__MCP__HttpSecurity` boundary canonicalizes configured
and incoming HTTP(S) origins through the standard URL parser, rejects non-origin URL
components and ambiguous host forms, and performs exact canonical allowlist membership.
`FrontmanCore__MCP__HttpRequest` runs this gate before an adapter-supplied authorization
callback, media validation, or body access. The callback receives an isolated header
snapshot rather than the request body and returns only `Authorized`, `MissingAuthentication`, or
`InsufficientAuthorization`; the latter outcomes emit empty `401` or `403` responses.
Accepted-origin responses echo that origin and set `Vary: Origin`. The active endpoint
accepts only explicitly configured adapters, validates preflight method and requested
headers, and returns authenticated `405` responses with `Allow: POST, OPTIONS`.

Next.js, Vite, and Astro configuration now accept the same optional explicit MCP security
input. It contains only an Origin allowlist and a header-only asynchronous authorization
callback with exact `authorized`, `missing-authentication`, and
`insufficient-authorization` outcomes. Configured origins are validated eagerly through the
shared policy. No adapter derives an allowlist from `clientUrl`, Frontman's remote `host`,
the request URL, `Host`, or forwarded headers. Vite and Astro register exact `/mcp` only
when this policy is supplied. Next.js generates a Node Pages API route with body parsing
disabled and rewrites public `/mcp` to it; the generated route requires
`FRONTMAN_MCP_TOKEN` and `FRONTMAN_MCP_ALLOWED_ORIGINS` and compares the bearer credential
with `timingSafeEqual`.
