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

| Direction | Maximum | Measurement | At limit | Over limit | Owner | Planned proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Incoming `/mcp` POST body | `2,097,152` bytes (2 MiB) | Raw bytes as received, before UTF-8 or JSON decoding. A valid `Content-Length` is checked before reading and the streaming reader independently counts actual bytes. | Continue to UTF-8, JSON, and protocol validation. | Return HTTP `413 Payload Too Large` with an empty body. Do not parse JSON, trust an ID, execute a tool, or persist data. | Shared Streamable HTTP request handler and each framework adapter, including the WordPress router | Send valid requests whose raw bodies are exactly `2,097,152` and `2,097,153` bytes; repeat with matching, missing, understated, and overstated `Content-Length`; assert no side effect on every rejection. |
| Streamable HTTP response consumed by the browser | `12,582,912` bytes (12 MiB) | Raw bytes read from an `application/json` body or cumulatively from an SSE response, including SSE framing. Count incrementally before concatenation or JSON decoding. | Continue response validation. | Abort the fetch and stream reader immediately, discard the entire response, and fail the originating request with local transport reason `response_body_limit_exceeded`. Never use or cache a partial result. | Browser Streamable HTTP client | Serve JSON and byte-split SSE responses exactly at and one byte over the maximum; assert reader cancellation, one terminal failure, no partial catalog/result, and no leaked fetch or reader. |

One Phoenix `mcp:message` payload is also limited to `2,097,152` UTF-8 bytes.
The custom transport closes an oversized WebSocket frame with close code `1009`.
If an adapter has already decoded an oversized event, the Phoenix connection owner
cancels affected work and closes the connection without accepting any request ID
from that event.

## JSON Nesting Depth

The maximum JSON nesting depth is `64`. A top-level object or array has depth 1;
entering an object or array value adds one. Scalars do not add depth. Depth is
measured over the complete JSON value, including `_meta`, schemas, tool arguments,
structured content, and embedded resource fields.

| At limit | Over limit | Owner | Planned proof test |
| --- | --- | --- | --- |
| A valid value at depth `64` proceeds to schema validation. | HTTP input returns HTTP `400` with JSON-RPC `-32700 Parse error` and `id: null`. A Phoenix frame is rejected before dispatch; it may receive `-32700` only if its ID was recovered independently without traversing the over-depth value, otherwise the connection is closed. No side effect occurs. | Shared bounded untyped JSON decoder used by the framework HTTP boundary, browser HTTP client, and Phoenix custom transport | Generate equivalent object and array fixtures at depths `64` and `65` for each boundary; assert deterministic rejection, no stack overflow, and no handler dispatch at `65`. |

## Metadata Bytes And Keys

Each `_meta` object has both limits below. Required MCP keys count toward the key
limit. Nested objects are included in the byte measurement and governed by JSON
depth, but only immediate members of that `_meta` object count as metadata keys.

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Planned proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Metadata bytes | `16,384` bytes | UTF-8 byte length of the compact JSON encoding of the complete `_meta` object. | Continue metadata schema and reserved-key validation. | Reject an HTTP request with HTTP `400` and JSON-RPC `-32602 Invalid params`; reject a Phoenix request with `-32602`. Reject an oversized response as a malformed peer response before persistence. | Shared MCP contract validator, browser HTTP client, and Phoenix connection owner | Build valid metadata encodings of exactly `16,384` and `16,385` bytes on requests and responses; assert round-trip preservation at the limit and rejection without dispatch or persistence over it. |
| Immediate metadata keys | `64` | Number of own keys directly in each `_meta` object after JSON parsing. | Continue validation. | Apply the same request or response behavior as the metadata byte limit. | Shared MCP contract validator | Validate `_meta` with exactly `64` and `65` valid keys, including required MCP keys, on every accepted message shape. |

## Tool Catalog

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Planned proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Assembled tools | `256` | Number of accepted tools accumulated across every remote page plus browser-local tools after invalid individual definitions are excluded. | Publish and cache the complete validated catalog. | Abort assembly before publishing. Do not select an arbitrary subset or replace a prior valid cache with partial data. Fail discovery with local reason `tool_count_limit_exceeded`. | Browser Streamable HTTP client and browser MCP server catalog owner | Assemble catalogs of `256` and `257` valid tools across one and multiple pages, including local tools; assert exact inclusion at the limit and no partial replacement over it. |
| One tool definition | `65,536` bytes (64 KiB) | UTF-8 byte length of the compact JSON encoding of one complete tool definition. | Continue schema and annotation validation. | Exclude only that tool, warn with tool name and categorical reason, and continue validating valid siblings. Never log the definition. | Browser remote tool-definition validator; Frontman-owned registries enforce the same limit at build/test time | Place definitions of exactly `65,536` and `65,537` bytes between valid siblings; assert acceptance at the limit, individual exclusion over it, and stable sibling order. |
| Complete catalog definitions | `1,048,576` bytes (1 MiB) | Sum of compact UTF-8 definition bytes for all accepted tools in the assembled catalog. | Publish and cache the complete validated catalog. | Abort catalog assembly with `catalog_bytes_limit_exceeded`; do not publish, truncate, or cache the partial catalog. | Browser Streamable HTTP client and browser MCP server catalog owner | Assemble accepted definitions totaling exactly `1,048,576` and `1,048,577` bytes across page boundaries; assert all-or-nothing publication. |

## Pagination

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Planned proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Pages | `32` | The initial `tools/list` response is page 1. Every response consumed increments the count once. | Accept page 32 only if it has no `nextCursor`; complete catalog assembly. | If page 32 has `nextCursor`, do not request page 33. Abort the listing with `pagination_page_limit_exceeded` and retain only a still-fresh prior cache. | Browser Streamable HTTP client | Serve terminating listings of 32 and 33 pages; assert exactly 32 requests in the over-limit case and no partial cache publication. |
| Repeated cursors | `0` repetitions tolerated | Track every present `nextCursor` by exact string value for one listing operation. The empty string is a valid cursor, participates in this set, and must be sent on the next request when first observed. | Any cursor value, including `""`, may appear once. | On the second appearance of the same value, abort before another page request with `pagination_cursor_repeated`; do not publish or cache partial results. | Browser Streamable HTTP client | Cover immediate and non-adjacent repetitions, including `"" -> ""` and `"" -> "a" -> ""`; assert the first empty cursor is sent and its repetition is rejected. |
| Cursor bytes | `4,096` bytes | UTF-8 byte length of each present cursor; empty string measures zero. | Send the cursor unchanged. | Abort listing with `pagination_cursor_limit_exceeded` before sending it. | Browser Streamable HTTP client | Exercise valid cursors of `0`, `4,096`, and `4,097` bytes and assert exact opaque preservation for accepted values. |

## Schema Safety

Limits apply separately to each `inputSchema` and `outputSchema`. Network,
file, data, and cross-document `$ref` values are never fetched. Internal fragment
references may resolve only inside the same bounded schema document. Unique schema
nodes are counted once even when reached by multiple local references.

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Planned proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Schema structural depth | `32` | Maximum nesting of schema-valued objects or arrays from the schema root. This is distinct from instance JSON depth. | Compile in an isolated validator. | Exclude the remote tool definition. A Frontman-owned generated schema exceeding the limit fails its build/test gate. | Browser remote JSON Schema 2020-12 validator; package tests for Frontman-owned schemas | Generate valid schemas at depths `32` and `33`, including composition and local references; assert individual remote exclusion and build-time failure for owned schemas. |
| Unique subschemas | `1,024` | Root plus every unique schema-valued descendant reached through JSON Schema keywords. Shared local-reference targets count once. | Compile in an isolated validator. | Apply the same remote exclusion or owned-schema build failure as structural depth. | Browser remote JSON Schema validator | Generate schemas with `1,024` and `1,025` unique nodes and shared-reference controls; assert deterministic counting. |
| Compile or instance validation duration | `100` milliseconds | Monotonic wall-clock time for one schema compilation or one instance-validation operation in an interruptible Worker or equivalent isolated execution context. | A result completed at or before `100 ms` is accepted. | Terminate the validation worker. Catalog compilation timeout excludes that tool. Input-validation timeout returns a complete `CallToolResult` with `isError: true` and does not execute. Output-validation timeout returns a bounded canonical protocol-error result; because execution may already have occurred, record that fact and never retry automatically. | Browser remote schema-validation worker and framework execution boundary | Under fake/controlled time, complete at `100 ms` and exceed at `101 ms` for compilation, input, and output validation; assert worker termination, no input-timeout side effect, and no output-timeout replay. |

## Tool Results And Media

| Limit | Maximum | Measurement | At limit | Over limit | Owner | Planned proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Result content blocks | `64` | Number of entries in `CallToolResult.content`, including every standard block type. Empty content is valid. | Validate and preserve all 64 blocks. | Reject the entire peer result before persistence. Complete the durable tool call once with a small canonical protocol-error result. Never truncate blocks. | Canonical result validator at the persistence boundary | Pass results containing `0`, `64`, and `65` valid mixed content blocks through live delivery, persistence, ACP, history replay, and model conversion. |
| Decoded media per block | `8,388,608` bytes (8 MiB) | Decoded bytes for image data, audio data, or an embedded blob. Preflight Base64 length and decode incrementally. | Preserve the valid block subject to the aggregate limit. | Stop decoding, reject the entire result before persistence, and resolve once with the canonical protocol-error result. Invalid Base64 follows the same path. | Canonical result validator | Test valid Base64 decoding to exactly `8,388,608` and `8,388,609` bytes for image, audio, and embedded blob blocks, plus invalid Base64 near the boundary. |
| Decoded media per result | `8,388,608` bytes (8 MiB) | Sum of decoded image, audio, and embedded-blob bytes across all content blocks. Text and resource links do not consume this budget. | Preserve the complete result. | Reject the complete result before persistence; never preserve only the blocks that fit. | Canonical result validator | Split exactly-at-limit and over-limit media across multiple block types and assert all-or-nothing persistence. |

## Request Timeouts

Every request records a monotonic start time, one immutable absolute deadline,
one idle timer where applicable, a pending owner, and a cancellation mechanism.

| Timeout | Value | Measurement | At limit | Over limit | Owner | Planned proof test |
| --- | ---: | --- | --- | --- | --- | --- |
| Idle | `60,000` milliseconds | Inactivity while receiving a request body or after HTTP response headers establish a JSON/SSE response stream. Valid received bytes, including SSE comment bytes, reset idle time. Waiting for initial response headers is governed by the absolute deadline, not a separate idle deadline. | Activity at exactly `60,000 ms` resets the timer. | Abort body/stream/fetch and cancellable work, remove pending state once, mark the ID recent, and return one timeout outcome. Later bytes or responses are ignored. | Shared HTTP body reader, browser Streamable HTTP client, and adapter cancellation bridge | Fake time around `60,000` and `60,001 ms`; cover JSON, SSE data, SSE comments, body upload, timeout/completion races, and timer cleanup. |
| Absolute | `600,000` milliseconds (10 minutes) | Elapsed monotonic time from immediately before request send. It never resets for progress, keepalive, retry, or activity. | A terminal response committed at the deadline wins atomically. | Atomically remove pending state, mark the ID recent, propagate cancellation through Phoenix, browser, fetch/reader, framework context, and ownership state, then produce one timeout result. A later completion cannot persist. | Issuing browser transport and Phoenix `TasksChannel` connection owner | Fake time at `600,000` and `600,001 ms`; exercise response, cancellation, disconnect, and lease races and assert one terminal outcome with no leaked timers or work. |

## Late-Response Tracking

Each Phoenix MCP connection retains at most `4,096` terminal request IDs for
`900,000` milliseconds (15 minutes). Each entry contains ID with exact JSON type,
request kind/method, terminal reason, terminal time, and former execution owner.
Expired entries are removed first; capacity then evicts the oldest entry. Eviction
does not reject a new request and IDs are never reused within a connection.

| At limit | Over limit | Owner | Planned proof test |
| --- | --- | --- | --- |
| Retain all `4,096` unexpired entries. A response for one is classified as duplicate or late, ignored, and counted. | Inserting entry `4,097` evicts exactly the oldest retained entry. Any response without a matching pending entry remains unable to complete any request, whether it is retained-recent or unknown. | Existing Phoenix `TasksChannel` connection owner | Under fake time, fill `4,096`, add one, expire entries at `900,000`/`900,001 ms`, and send late, duplicate, unknown, numeric-ID, and string-ID responses in randomized order; assert no cross-completion or second persistence. |

## Durable Ownership Lease

The execution claim lease is `60,000` milliseconds and is renewed every
`20,000` milliseconds while the owning MCP connection is healthy. Lease timestamps
use database time. Acquisition, renewal, expiry takeover, and terminal completion
use atomic compare-and-set operations keyed by durable `tool_call_id`.

| At limit | Over limit | Owner | Planned proof test |
| --- | --- | --- | --- |
| Through the exact expiration instant, only the current owner may send, retry, cancel, or accept a response. A renewal committed at the instant extends the lease. | After expiration, exactly one contender may atomically claim. The former owner may no longer renew or resolve, and its late result is ignored. Disconnect attempts immediate release rather than waiting for expiry. | Tasks persistence as durable claim authority; Phoenix connection owner as lease holder | Use database-controlled time and competing processes/nodes at `60,000` and `60,001 ms`; prove one winner, renewal every `20,000 ms`, immediate disconnect release, former-owner rejection, and transactional result completion. |

Lease takeover does not imply automatic execution replay. If the previous owner may
have begun a non-idempotent side effect and no terminal result proves its outcome,
Frontman marks the call as requiring explicit user resolution. It must not resend the
tool call automatically. Automatic owned retry is allowed only when no execution began
or when the tool has a verified idempotency guarantee bound to the preserved durable
tool-call identifier.

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

The Origin proof suite covers exact allowed origins, scheme/host/port changes, missing,
`null`, malformed, duplicate, userinfo, trailing-dot, encoded-host, hostile DNS-rebinding,
and preflight requests and asserts zero tool side effects on every rejection.
