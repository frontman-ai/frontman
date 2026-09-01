# Phase 6 Durable Ownership Research

## Decision Boundary

BlueHotDog approved the existing-row persisted-data-shape change on `2026-08-13`. The implemented design adds no table, column, index, constraint, or migration.

## Existing Persistence

Each interaction already has a UUID primary key, task identity, interaction type, turn number, and non-null JSONB `data`. A tool-call interaction stores the durable tool-call identifier, tool name, arguments, and timestamp. Tool results are separate interaction rows protected by a unique partial index over task, turn, and tool-call identifier.

The result uniqueness constraint prevents a second canonical result from being stored. It does not prevent two owners from performing the same external side effect before either result is stored. Current unresolved-call recovery identifies tool calls without result rows and redispatches them without durable ownership state.

## Rejected Lock-Only Designs

Transaction-scoped advisory locks and row locks can serialize a short acquisition transaction. They cannot retain ownership after that transaction commits. Holding either lock across browser execution would create a long-running transaction and pin a pooled database connection without adding lease generation or former-owner fencing.

Session-scoped advisory locks can retain one active database-session owner and release after PostgreSQL detects connection loss. They cannot provide the frozen database-time lease boundary, explicit generation, durable cancellation state, transactional result fencing after takeover, or bounded failover independent of connection-failure detection. They would also dedicate one pooled connection to each active tool execution.

The node-local Registry and process monitors remain useful for live addressing and prompt failover. They cannot arbitrate competing Phoenix nodes or preserve ownership through process and node loss.

The existing tool-result uniqueness index prevents duplicate persistence only after execution. It is not execution ownership authority.

## Smallest Sound Design Direction

The existing tool-call interaction row can be the durable claim authority without database DDL if approval permits adding a namespaced claim object to its existing JSONB value and declaring that state in the `Interaction.ToolCall` embedded schema. The current polymorphic embed loads and dumps only declared fields, so raw SQL claim keys would otherwise disappear from typed reads and could be lost by a later full embed dump.

The claim must contain:

- Globally unique MCP connection owner identity.
- Monotonically increasing ownership generation.
- Database-time lease expiration.
- Dispatch state distinguishing claimed work from work that may have begun.
- Resolution or cancellation state.
- Replay policy for verified idempotent and potentially non-idempotent work.

Every operation must use short atomic compare-and-set transactions against the interaction UUID primary key. Row locks and transaction-scoped advisory locks may serialize these short operations, but they are not durable authority by themselves:

1. Acquire only when unclaimed, explicitly released, or expired.
2. Renew only when owner and generation still match.
3. Record that dispatch may begin before sending `tools/call`.
4. Release orderly disconnects only for the matching owner and generation.
5. Allow one takeover winner only after lease expiration.
6. Verify owner, generation, lease, unresolved state, and row identity before accepting a result.
7. Insert the canonical tool result and complete the claim in one transaction.
8. Reject former-owner and late results before persistence.

Steady-state claim operations should use the interaction UUID primary key. Recovery APIs must retain that row identity instead of returning only decoded interaction data.

The database currently guarantees uniqueness for tool-result identity but not tool-call identity. Claiming two duplicate tool-call rows by separate UUIDs could therefore produce two owners for one durable tool-call identifier. If a partial unique tool-call index is not approved, creation and claim acquisition must use transaction-scoped serialization over the logical task, turn, and tool-call identity and fail loudly unless exactly one row exists. This avoids DDL but requires controlled database concurrency proof before the design can be accepted.

## Replay Safety

Lease takeover does not prove that a previous external side effect did not occur. If dispatch may have begun and the tool has no verified idempotency guarantee bound to the durable tool-call identifier, takeover must produce an explicit ambiguous state requiring user resolution. It must not automatically resend the call.

Automatic replay is safe only when durable state proves dispatch never began or the selected tool provides a verified idempotency guarantee using the preserved durable identifier.

## Implementation Status

The claim object is declared in the existing `Interaction.ToolCall` embed and stored in its JSONB row. Short transactions serialize logical identity through the task row, lock the exact interaction, use database time, and fence every owner generation. Dispatch intent is persisted before browser send; canonical result insertion and claim completion or cancellation are one transaction.

Controlled repository tests prove typed round trips, logical-identity serialization, competing acquisition over independent PostgreSQL connections, lease renewal and takeover, exact database-time boundaries, graceful cancellation, former-owner fencing, dispatch ambiguity, and transactional result completion. Browser tests prove durable-ID replay joining, changed-replay rejection, hard active-execution capacity, and fail-closed bounded tombstones.

Whole-phase acceptance still requires actual distributed Phoenix-node and crash-boundary fault injection. No process-only or lock-only substitute should be presented as that remaining proof.
