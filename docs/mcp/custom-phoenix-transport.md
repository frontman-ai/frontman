# MCP Custom Phoenix Transport

Frontman carries MCP `2026-07-28` between its authenticated Phoenix server and browser over the custom transport defined here.

## Connection

The transport uses the existing authenticated Phoenix socket. Each joined `tasks` channel is a connection candidate; `MCPConnection` deterministically selects one connection owner per authenticated user. That owner performs MCP discovery, project-context calls, ordinary browser calls, correlation, cancellation, and reconnect redispatch. Joined `task:<task-id>` channels are ACP observers and runner gates; they do not own MCP requests or responses. Authentication and authorization are inherited from the socket and channels. MCP metadata does not grant access and does not replace application authorization.

Each `mcp:message` Phoenix event contains exactly one decoded JSON-RPC message. Batches are not supported. The payload must satisfy the shared MCP JSON-RPC schemas and the limits in `implementation-limits.md`.

## Direction

The Phoenix peer sends `server/discover`, `tools/list`, and `tools/call` requests plus `notifications/cancelled`. The browser peer sends success or error responses for requests. Unsupported requests receive the standard method-not-found error. Notifications never receive responses. Messages in the wrong direction are ignored and cannot execute tools.

Every request is stateless and includes the protocol version and client capabilities in `_meta`. Every `tools/call` also includes `ai.frontman/execution-context` with explicit task and durable tool-call identifiers. Neither peer infers MCP context from a prior request or negotiated connection state.

## Ordering And Correlation

Phoenix preserves event order on one joined channel. `session/load` history and its success response are pushed before that load can release agent execution or produce a browser `tools/call`. For frameworks requiring project context, the task observer waits for both a terminal catalog and an owner-scoped project-context readiness broadcast. The owner broadcasts readiness only after rules and structure have persisted, or after absent tools, disabled framework loading, nonfatal failure, or timeout makes hydration terminal. Requests may execute concurrently and responses may complete in any order. Correlation uses the exact string or safe-integer JSON-RPC ID. The browser permits at most 256 underlying active durable executions per handler, charges cancelled but unsettled work until settlement, joins structurally identical replays by task and durable tool-call identity, and rejects changed replays without starting a second execution.

The browser server enforces a fixed window of 256 new underlying tool executions per 60 seconds before consent or dispatch. Execution 257 returns a complete tool error, and the exact expiry starts a new window. Identical active joins and completed durable replays do not execute the tool and do not consume another slot; a rejected durable identity remains terminal under the same exact-replay contract. This is independent of the 256-execution active bound and fail-closed 4,096-key plus 1 MiB fingerprint handler-lifetime bounds; the selected connection owner separately enforces the server-side pending-request bound.

Browser call results, including tool errors, merge `io.modelcontextprotocol/serverInfo`
into `_meta` while preserving other result metadata. The Phoenix client normalizes an
absent `resultType` to `complete`; a valid `input_required` call result is recognized and
resolved as one canonical unsupported-input tool error without automatic retry.

## Cancellation

Phoenix sends `notifications/cancelled` with the exact active request ID. The browser removes that request from active correlation before aborting its signal. Cancellation therefore wins against later completion and no late response is sent. Cancelling one ID does not affect sibling requests.

ACP task cancellation asks the connection owner to atomically persist a canonical terminal cancellation for each matching durable claim, cancel matching browser requests, and cancel the supervised task execution. A late browser response cannot persist a result or replace the terminal claim state.

## Teardown And Replay

The browser owns the exact Phoenix listener reference returned by `Channel.on`. Detach removes only that listener, marks the handler inactive, aborts its active calls, and suppresses their late responses. Session cleanup cannot remove another MCP listener.

On graceful owner departure, every pending claimed tool is transactionally cancelled before `MCPConnection` selects one successor. Task observers discard readiness from the former owner and re-gate required project context against the successor. Abrupt loss leaves the database-time lease and generation authoritative: work not marked as dispatched may be claimed after expiry, verified-idempotent work may retain its durable replay identity, and started non-idempotent work becomes an explicit terminal ambiguity instead of being blindly resent. If no successor exists, affected executions are cancelled through SwarmAi lifecycle cleanup, owner-local correlation is cleared with channel teardown, and observers receive an unavailable catalog.

Phoenix delivery remains transient, but execution authority is durable. The existing tool-call interaction JSONB row stores the declared claim owner, generation, database-time lease, dispatch state, resolution state, and replay policy. Reconnect recovery must acquire that claim before sending a new JSON-RPC ID with the same `ai.frontman/execution-context.toolCallId`; former generations cannot renew, cancel, or complete it. Registry, ETS, and PubSub remain live-addressing mechanisms rather than ownership authority.

## Attachment Resolution

Framework tools that accept browser-held attachments advertise `ai.frontman/attachment-resolution` in their tool `_meta`. Version 1 names the reference, content, encoding, and optional media-type arguments and states whether the reference is removed. The browser performs resolution only from this metadata and explicit task context; tool names do not activate hidden behavior.

Peers that do not understand this metadata leave arguments unchanged. A malformed or unsupported Frontman attachment-resolution value fails the call without sending attachment bytes.
