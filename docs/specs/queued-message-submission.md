# Spec: Queued Message Submission

## Objective

Show every submitted prompt in queued-message drawer while server acceptance is pending. Send prompts immediately so server persists and schedules them.

## Commands

- Build and test: `make -C libs/client test`
- Dead-code analysis: `make reanalyze`
- Shared client checks: `make -C libs/frontman-client check`

## Project Structure

- `libs/client/src/state/`: queued-message state and transitions
- `libs/client/src/components/frontman/`: queued-message drawer
- `libs/client/src/Client__Chatbox.res`: submission and drawer integration
- `libs/client/test/`: reducer and integration coverage

## Code Style

Use typed ReScript state transitions and pattern matching. Keep API side effects in StateReducer.

## Testing Strategy

- Reducer tests prove prompts enter queue and acknowledgements reconcile by ID without affecting later submissions.
- Integration test proves first prompt appears in drawer before session creation completes.

## Boundaries

- Always: send queued prompts to server immediately.
- Always: preserve task ownership and message UUID.
- Never: put replayed history messages in queued drawer.
- Never: let failed prompts remain queued.

## Success Criteria

- First prompt appears in queued drawer before session activation.
- Prompts remain queued until server acknowledgement or definitive send failure.
- Server acknowledgement moves only matching prompt into transcript.
- Failed prompts leave queue and retain attempted content beside error.
- Existing message-submission race tests pass.

## Implementation Plan

1. Restore queued-message state transitions and write failing reducer tests.
2. Restore drawer and wire optimistic staging through queue.
3. Add first-prompt integration coverage and run full verification.
