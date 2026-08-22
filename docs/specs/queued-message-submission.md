# Spec: Queued Message Submission

## Objective

Show each submitted prompt until server execution starts. Keep server acceptance and execution as separate states.

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

- Reducer tests prove that prompts enter the queue and server events reconcile by ID.
- Reducer tests prove immediate queue insertion before session readiness, and component coverage proves drawer rendering.

## Boundaries

- Always: prepare prompts and send them in submission order.
- Always: preserve task ownership and message UUID.
- Never: put replayed history messages in queued drawer.
- Never: let failed prompts remain queued.
- Never: remove a prompt from the drawer on server acceptance.

## Success Criteria

- First prompt appears in queued drawer before session activation.
- Prompts remain queued until execution starts or submission fails.
- Server acceptance moves canonical content into the transcript.
- An execution-start update removes only the prompt with the matching UUID.
- A late transport error does not fail an accepted prompt.
- Failed prompts leave queue and retain attempted content beside error.
- Existing message-submission race tests pass.

## Implementation Plan

1. Store each submission in application reducer state.
2. Prepare attachments and activate sessions through reducer effects.
3. Reconcile acceptance and execution-start events by UUID.
4. Render the submission store in the drawer.
