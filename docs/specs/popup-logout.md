# Popup Logout

## Objective

Log out from embedded Frontman clients without navigating their host page or relying on third-party iframe cookies. Logout runs in a user-opened API tab, closes that tab after completion, disconnects the current ACP session, and returns the embedded client to its sign-in state.

## Commands

- Client tests: `make -C libs/client test`
- Client build: `make -C libs/client build-standalone`
- Server tests: `mix test test/frontman_server_web/controllers/user_session_controller_test.exs test/frontman_server_web/channels/user_socket_test.exs`
- Server checks: `mix precommit`

## Project Structure

- `apps/frontman_server/`: logout endpoint, completion page, socket authentication, and tests
- `libs/client/`: connection reducer, provider contract, settings UI, and tests
- `test/e2e/`: browser coverage where authenticated production credentials are available

## Code Style

Use explicit reducer actions and effects for asynchronous work. Use Phoenix controller routes for CSRF-protected session mutation. Open authentication pages with semantic links under direct user activation.

## Testing Strategy

- Controller tests prove popup mode preserves CSRF protection, deletes session, and redirects to public completion page.
- Socket tests prove deleted sessions cannot authenticate and current-session sockets have a disconnect identity.
- Reducer tests prove logout disconnects ACP, polls authentication, and reaches auth-required state only after server confirmation.
- Browser verification proves Playground sandbox remains mounted when logout opens.

## Boundaries

- Always: use first-party API tab, `noopener`, CSRF-protected DELETE, session-bound socket authentication, and bounded polling.
- Ask first: changing logout from current-session scope to all-device scope.
- Never: navigate embedded host, expose session token to JavaScript, depend on `window.opener`, or mutate session from GET.

## Success Criteria

- Sign out opens `/users/log-out?mode=popup` in a new tab.
- Playground top URL and WordPress iframe remain unchanged.
- Successful DELETE redirects to public `/users/logout-complete`, which closes its tab.
- Client disconnects current ACP session and polls `/api/socket-token` until `401`.
- Client returns to sign-in state after confirmed logout and reports bounded polling failures.
- Socket tokens are bound to a live browser session; logout disconnects that session and prevents stale-token reconnects.

## Open Questions

None.
