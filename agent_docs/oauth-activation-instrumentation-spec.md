# Spec: OAuth Activation Instrumentation

## Objective

Measure client-only activation transitions in Heap without treating browser analytics as authoritative backend state. PostgreSQL remains authoritative for OAuth completion, credentials, task creation, and accepted prompts.

## Tech Stack

- ReScript client and React
- Reducer-owned side effects
- Heap browser SDK
- Vitest tests

## Commands

- Build: `make -C libs/client build`
- Test: `make -C libs/client test`
- Relay check: `make -C libs/frontman-client check`
- Source check: `make check-source-comments`

## Project Structure

- `libs/client/src/Client__Heap.res`: typed Heap boundary
- `libs/client/src/Client__ConnectionReducer.res`: relay, session creation, and prompt transport transitions
- `libs/client/src/state/Client__State__StateReducer.res`: authenticated profile and analytics identity
- `libs/client/src/Client__App.res`: provider blocker visibility
- `libs/client/src/Client__Chatbox.res`: accepted prompt submission
- `libs/client/test`: reducer and interaction tests

## Code Style

Use closed variants and pattern matching so event names and properties cannot be supplied dynamically.

```rescript
type relayOutcome = Success | Failure(relayFailureReason)

let track = event =>
  switch event {
  | RelayDiscoveryCompleted({framework, outcome}) => // fixed event and property mapping
  }
```

## Testing Strategy

- Test typed event conversion without loading external Heap scripts.
- Test reducer effects at accepted transition boundaries.
- Test provider visibility across render, re-render, close, and reopen.
- Verify Strict Mode and stale reducer results do not duplicate client invocations.
- Verify production behavior in Heap development environment with fresh browser storage.

## Boundaries

- Always: use normalized `framework`, `outcome`, and `reason_code` values.
- Always: treat one invocation as guarantee; Heap ingestion remains best effort.
- Ask first: add database persistence, server-side Heap API, dependencies, or new PII.
- Never: track prompts, credentials, URLs, domains, paths, response bodies, status text, parser details, or exception messages.
- Never: describe client events as authoritative OAuth, task, or prompt-acceptance facts.

## Event Contract

| Event | Trigger | Properties |
|---|---|---|
| `authenticated_client_identified` | Successful `/api/user/me` parse, after `heap.identify` invocation | `framework` |
| `local_relay_discovery_completed` | Accepted non-aborted relay attempt settles | `framework`, `outcome`, optional `reason_code` |
| `provider_setup_blocker_shown` | Blocking modal changes hidden to visible | `framework` |
| `prompt_submission_initiated` | Chatbox accepts non-empty submission | `framework` |
| `task_creation_requested` | Accepted creation effect before `session/new` | `framework` |
| `prompt_request_sent` | Immediately before `session/prompt` transport | `framework` |

Allowed relay failure reasons: `http_error`, `invalid_response`, `network_error`, `unknown`.

## Success Criteria

- All event names and properties are typed and allowlisted.
- Authenticated identification can complete when relay discovery fails.
- Strict Mode, reconnects, re-renders, and stale reducer results do not create false duplicates.
- Submission, task creation, and prompt transport remain separate transitions.
- Client tests and build pass.
- Changeset records user-visible analytics instrumentation.

## Open Questions

- Heap plan, export capability, consent behavior, and production cohort reconciliation remain rollout decisions outside implementation scope.
