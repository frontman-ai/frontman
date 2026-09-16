# Embedded Client Authentication Implementation Plan

## Goal

Replace cross-origin session-cookie authentication for embedded Frontman clients with a long-lived, revocable opaque bearer token. Embedded clients must work on arbitrary approved customer origins without third-party cookies and without repeated user login prompts.

## Security Issue Being Fixed

Protected central APIs currently authenticate embedded clients through a Frontman session cookie. The API also allows credentialed CORS. In browsers that send unpartitioned third-party cookies, a hostile origin can cause the victim browser to send the victim's Frontman session cookie to protected APIs. That can read or mutate protected resources and can mint a reusable socket token.

The fix is to stop using ambient cross-origin cookies for embedded APIs and sockets. Protected embedded APIs and sockets must require an explicit origin-scoped bearer token. A hostile origin may still send requests, but it cannot authenticate unless it has the bearer token, and it cannot read a token stored under another browser origin's `localStorage`.

## Existing Platform Capabilities To Reuse

Do not add a broad auth library for this work. Phoenix already provides most of the needed infrastructure:

- Existing `phx.gen.auth`-style browser login, session, remember-me, magic-link, password, and WorkOS/social login flow.
- Existing `current_scope` authentication contract.
- Existing `users_tokens` table and `FrontmanServer.Accounts.UserToken` token patterns.
- Existing Plug router pipelines.
- Existing browser-pipeline CSRF protection through `protect_from_forgery`.
- Existing secure browser headers through `put_secure_browser_headers`.
- Phoenix JS `Socket` support for `authToken`, which sends the token via WebSocket subprotocol instead of query params.
- Phoenix PubSub for socket disconnect on revocation.

Avoid adding Guardian, Pow, Ueberauth, OAuth-provider libraries, or JWT infrastructure. The desired token is opaque, stored hash-only, and app-specific.

## PR Size Rule

Never open a PR with more than 500 changed lines.

Target 150-350 changed lines per PR. If a step grows beyond 500 changed lines, split it before opening the PR. Every PR must check:

```bash
git diff --stat
git diff --shortstat
```

Each PR should include focused implementation, focused tests, and cleanup for only the files touched. Do not do unrelated opportunistic refactors.

## Step 1: Add Embedded Token Foundation, No Route Changes — DONE

### Status

Implemented in this working tree:

- Reused the existing `users_tokens` table; no new token table was added.
- Added nullable embedded-token metadata fields: `approved_origin`, `expires_at`, `last_used_at`.
- Added hash-only opaque embedded-client token generation under context `embedded_client`.
- Added embedded-token verification with expiration checks.
- Added Accounts APIs for generation, lookup, last-used tracking, single-token revocation, and account-wide embedded-token revocation.
- Kept `%UserToken{}` as an Accounts-internal persistence detail for embedded auth by returning `{%Scope{}, token_id}` from lookup.
- Added focused Accounts tests for valid/invalid/expired token behavior, hash-only storage, `last_used_at`, and revocation.

Verification completed:

```bash
cd apps/frontman_server && MIX_ENV=test mix ecto.migrate
cd apps/frontman_server && mix test test/frontman_server/accounts_test.exs
cd apps/frontman_server && mix format --check-formatted
cd apps/frontman_server && mix compile --warnings-as-errors --all-warnings
```

Implementation files:

- `apps/frontman_server/priv/repo/migrations/20260830000000_add_embedded_client_fields_to_users_tokens.exs`
- `apps/frontman_server/lib/frontman_server/accounts/user_token.ex`
- `apps/frontman_server/lib/frontman_server/accounts.ex`
- `apps/frontman_server/test/frontman_server/accounts_test.exs`

### Goal

Create the new credential type behind the scenes while leaving current routes, sockets, CORS, and client behavior unchanged.

### Scope

Add token metadata to `users_tokens` if the existing schema cannot represent the required metadata:

- `approved_origin`
- `expires_at`
- `last_used_at`

Extend `FrontmanServer.Accounts.UserToken` and `FrontmanServer.Accounts` with embedded-client token support:

- generate 32 random bytes for the raw token
- store only SHA-256 hash
- use a dedicated context such as `embedded_client`
- store owning user ID
- store approved origin
- store expiration time
- support last-used tracking
- support individual revocation
- support account-wide embedded-token revocation

### Existing Code To Read First

- `apps/frontman_server/lib/frontman_server/accounts/user_token.ex`
- `apps/frontman_server/lib/frontman_server/accounts.ex`
- `apps/frontman_server/priv/repo/migrations/20260116085749_create_users_auth_tables.exs`
- `apps/frontman_server/test/frontman_server/accounts_test.exs`
- `apps/frontman_server/test/support/fixtures/accounts.ex`

### Cleanup While Touching

- Keep the session, magic-link, and email-change token behavior unchanged.
- Do not weaken struct contracts to maps. Follow `apps/frontman_server/BOUNDARY_CONTRACT_POLICY.md`.
- Keep token queries close to the `UserToken` schema, matching existing style.

### Suggested PR Split

If needed, split into:

1. migration + schema fields
2. `UserToken` helpers + tests
3. `Accounts` public API + tests

Each PR must stay below 500 changed lines.

### Verification

```bash
cd apps/frontman_server && mix test test/frontman_server/accounts_test.exs
cd apps/frontman_server && mix format --check-formatted
```

## Step 2: Add Bearer API Auth And Migrate Protected HTTP Routes — DONE

### Status

Implemented in this working tree:

- Added `FrontmanServerWeb.UserAuth.require_embedded_client_bearer_token/2`.
- Added exact-one `Authorization` header enforcement.
- Added `Bearer <token>` parsing and rejection for missing, duplicate, malformed, invalid, expired, or revoked tokens.
- Reused Step 1 `Accounts.get_scope_by_embedded_client_token/1` verification.
- Assigned `current_scope` and `embedded_client_token_id` for authenticated bearer requests.
- Touched `last_used_at` through `Accounts.touch_embedded_client_token/1` after successful bearer auth.
- Added shared API unauthorized response cleanup in `UserAuth`.
- Added router pipeline `:bearer_api`.
- Migrated protected HTTP route groups from `:api_with_session` to `:bearer_api`:
  - `GET /api/user/me`
  - `GET/POST /api/user/api-keys`
  - custom provider CRUD routes
  - Anthropic OAuth API routes
  - OpenAI OAuth API routes
- Deleted now-empty `:api_with_session` and its unused session-auth API plug.
- Added `FrontmanServerWeb.ConnCase.put_embedded_client_bearer/3` test helper.
- Added focused bearer plug tests.
- Updated route tests to use bearer auth and prove session-only auth returns `401`.

Learning: These URLs are active client API contracts; Step 2 changes their authentication only, not their paths or controllers.

Verification completed:

```bash
cd apps/frontman_server && mix test test/frontman_server_web/controllers/user_api_key_controller_test.exs test/frontman_server_web/controllers/custom_providers_controller_test.exs test/frontman_server_web/controllers/anthropic_oauth_controller_test.exs test/frontman_server_web/controllers/openai_oauth_controller_test.exs test/frontman_server_web/controllers/user_me_controller_test.exs test/frontman_server_web/user_auth_test.exs
cd apps/frontman_server && mix format --check-formatted
```

Implementation files:

- `apps/frontman_server/lib/frontman_server_web/user_auth.ex`
- `apps/frontman_server/lib/frontman_server_web/router.ex`
- `apps/frontman_server/test/support/conn_case.ex`
- `apps/frontman_server/test/frontman_server_web/user_auth_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/user_me_controller_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/user_api_key_controller_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/custom_providers_controller_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/anthropic_oauth_controller_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/openai_oauth_controller_test.exs`

### Goal

Make protected embedded HTTP APIs ignore Frontman session cookies and authenticate only through the embedded bearer token.

### Scope

Add a bearer-auth plug, likely in `FrontmanServerWeb.UserAuth`, that:

- requires exactly one `Authorization` header
- requires the value to be `Bearer <token>`
- rejects missing, duplicate, malformed, invalid, expired, or revoked tokens with `401`
- verifies using the embedded-client token APIs from Step 1
- assigns `current_scope`
- assigns the embedded token record ID for revocation/auditing

Add the `:bearer_api` router pipeline and migrate protected route groups from `:api_with_session` to bearer auth in small PRs.

Completed route-group order:

1. `GET /api/user/me` — DONE
2. `GET/POST /api/user/api-keys` — DONE
3. custom provider CRUD routes — DONE
4. Anthropic OAuth API routes — DONE
5. OpenAI OAuth API routes — DONE

### Existing Code To Read First

- `apps/frontman_server/lib/frontman_server_web/user_auth.ex`
- `apps/frontman_server/lib/frontman_server_web/router.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/user_me_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/user_api_key_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/custom_providers_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/anthropic_oauth_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/openai_oauth_controller.ex`
- matching controller tests under `apps/frontman_server/test/frontman_server_web/controllers/`

### Cleanup While Touching

- Remove session-auth assumptions from migrated route tests.
- Add a small shared test helper for embedded bearer auth if tests start duplicating setup.
- Keep `:api_with_session` only while routes still use it.
- Delete `:api_with_session` once empty, but only in the PR that empties it.

### Suggested PR Split

Use one PR for the bearer plug and one PR per route group. Each PR should be 150-400 changed lines.

### Verification

Run only the test file relevant to the PR, for example:

```bash
cd apps/frontman_server && mix test test/frontman_server_web/user_auth_test.exs
cd apps/frontman_server && mix test test/frontman_server_web/controllers/user_me_controller_test.exs
cd apps/frontman_server && mix test test/frontman_server_web/controllers/user_api_key_controller_test.exs
cd apps/frontman_server && mix test test/frontman_server_web/controllers/custom_providers_controller_test.exs
cd apps/frontman_server && mix test test/frontman_server_web/controllers/anthropic_oauth_controller_test.exs
cd apps/frontman_server && mix test test/frontman_server_web/controllers/openai_oauth_controller_test.exs
```

## Step 3: Add Popup Authorization And Consent Flow — DONE

### Status

Implemented in this working tree:

- Added strict embedded client origin normalization with HTTPS-only production origins and explicit localhost HTTP development origins.
- Rejected `null`, opaque origins, credentials, paths, queries, and fragments.
- Added one named pending embedded auth session key.
- Stored normalized `embedded_origin` and `embedded_state` from the login page.
- Used explicit `{:ok, conn}` / `{:error, conn}` controller flow for invalid embedded origins instead of checking `conn.halted` after sending a response.
- Preserved pending embedded auth requests through password and magic-link login by restoring the request after session renewal.
- Reused `/users/popup-complete` as the consent and completion path instead of adding a parallel login system.
- Added an authenticated consent screen that displays the exact normalized origin.
- Added CSRF-protected approval through the browser pipeline.
- Created the embedded client token only after approval.
- Returned completion HTML with `Cache-Control: no-store` and an exact-origin completion payload carrying the versioned message, state, and token.
- Moved popup-completion JavaScript into the existing `app.js` bundle to avoid inline template scripts.
- Removed the obsolete close-only popup completion template and standalone JavaScript bundle entry.

Implementation files:

- `apps/frontman_server/lib/frontman_server_web/embedded_client_auth.ex`
- `apps/frontman_server/lib/frontman_server_web/embedded_client_origin.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/embedded_client_auth_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/embedded_client_auth_html.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/embedded_client_auth_html/show.html.heex`
- `apps/frontman_server/lib/frontman_server_web/controllers/embedded_client_auth_html/missing.html.heex`
- `apps/frontman_server/lib/frontman_server_web/controllers/embedded_client_auth_html/complete.html.heex`
- `apps/frontman_server/assets/js/app.js`
- `apps/frontman_server/lib/frontman_server_web/controllers/user_session_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/user_auth.ex`
- `apps/frontman_server/lib/frontman_server_web/router.ex`
- `apps/frontman_server/config/config.exs`
- `apps/frontman_server/test/frontman_server_web/embedded_client_origin_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/embedded_client_auth_controller_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/user_session_controller_test.exs`

Removed files:

- `apps/frontman_server/assets/js/popup-complete.js`
- `apps/frontman_server/lib/frontman_server_web/controllers/user_session_html/popup_complete.html.heex`

Verification completed:

```bash
cd apps/frontman_server && mix test test/frontman_server_web/embedded_client_origin_test.exs test/frontman_server_web/controllers/embedded_client_auth_controller_test.exs test/frontman_server_web/controllers/user_session_controller_test.exs
cd apps/frontman_server && mix test test/frontman_server_web/controllers/oauth_controller_test.exs
cd apps/frontman_server && mix format --check-formatted
cd apps/frontman_server && mix compile --warnings-as-errors --all-warnings
```

### Goal

Allow the approved customer origin to obtain an embedded-client bearer token through a first-party Frontman popup.

### Scope

Add strict origin normalization and validation:

- accept normalized HTTPS origins
- allow HTTP only for explicit localhost development cases
- reject `null` and opaque origins
- reject credentials, paths, queries, and fragments

Add a pending embedded authorization request in the browser session:

- preserve `state`
- preserve normalized requesting origin
- preserve through password login, magic-link login, and WorkOS/social login
- use one named session key

Add consent and approval:

- show the exact normalized origin
- require explicit approval
- rely on normal browser-pipeline CSRF protection
- create the embedded token on approval
- return a popup completion response with `Cache-Control: no-store`
- send `{type, state, token}` through `postMessage` to the exact approved `targetOrigin`
- never place the token in a URL, log, telemetry event, or error response

### Existing Code To Read First

- `apps/frontman_server/lib/frontman_server_web/controllers/user_session_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/oauth_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/user_session_html/new.html.heex`
- `apps/frontman_server/lib/frontman_server_web/controllers/user_session_html/popup_complete.html.heex`
- `apps/frontman_server/lib/frontman_server_web/components/layouts/root.html.heex`
- `apps/frontman_server/lib/frontman_server_web/router.ex`
- matching controller tests under `apps/frontman_server/test/frontman_server_web/controllers/`

### Cleanup While Touching

- Keep all browser authentication in the browser pipeline.
- Do not introduce a second login system.
- Do not introduce OAuth authorization-code or PKCE machinery.
- Keep popup-specific code isolated to a small controller/template path.
- Verify clickjacking protections rather than adding broad header changes without tests.

### Suggested PR Split

Split into small PRs:

1. origin normalization module + unit tests
2. pending request storage + login preservation tests
3. consent screen + CSRF approval tests
4. token creation + exact-origin `postMessage` tests

Each PR must stay below 500 changed lines.

### Verification

```bash
cd apps/frontman_server && mix test test/frontman_server_web/controllers/user_session_controller_test.exs
cd apps/frontman_server && mix test test/frontman_server_web/controllers/oauth_controller_test.exs
cd apps/frontman_server && mix test test/frontman_server_web/controllers/embedded_client_auth_controller_test.exs
cd apps/frontman_server && mix format --check-formatted
```

## Step 4: Migrate Client HTTP Auth And Popup Lifecycle — DONE

### Status

Implemented in this working tree. Three client slices are complete.

Current state:

- Protected central HTTP API calls in `libs/client/src/state/Client__State__StateReducer.res` no longer use `credentials: Include`.
- Profile, API-key, custom-provider, Anthropic OAuth, and OpenAI OAuth calls use the embedded bearer-token helper.
- The public update-check call no longer sends cookies.
- The popup login lifecycle is implemented in the client.
- The legacy `tokenUrl` logout/session probe was removed during Step 5 socket-token cleanup.

#### Slice 1: Credential Storage And Profile/API-Key Migration — DONE

Implemented:

- Added centralized embedded-token storage and bearer-header helpers in `libs/client/src/Client__EmbeddedAuth.res`.
- Added focused credential helper tests in `libs/client/test/Client__EmbeddedAuth.test.res`.
- Migrated profile and API-key HTTP calls in `libs/client/src/state/Client__State__StateReducer.res` away from `credentials: Include`.
- Added `401` cleanup for the migrated calls so revoked or expired tokens are removed from `localStorage`.
- Confirmed existing ReScript localStorage bindings are already used in the codebase via `WebAPI.Window.localStorage` and `WebAPI.Storage.*`; no `%raw` JavaScript or new binding was added.

Implementation files:

- `libs/client/src/Client__EmbeddedAuth.res`
- `libs/client/test/Client__EmbeddedAuth.test.res`
- `libs/client/src/state/Client__State__StateReducer.res`

Verification completed:

```bash
cd libs/client && make build
cd libs/client && make test
```

#### Slice 2: Shared Auth Dialog Reuse And Custom-Provider Migration — DONE

Implemented:

- Reused the existing `Client__WelcomeModal` auth-required dialog instead of adding custom-provider-specific auth UI.
- Added `RequireAuthentication` in `libs/client/src/Client__ConnectionReducer.res`.
- `RequireAuthentication` sets the existing `ACPAuthRequired({loginUrl})` state and drives the existing `authRedirectUrl` path.
- Exposed `requireAuthentication` from `libs/client/src/Client__FrontmanProvider.res`.
- Threaded `requireAuthentication` through `Client__App.res`, `Client__State.Actions.setAcpSession`, and `AcpSessionActive`.
- Migrated custom-provider fetch, save, update, and delete calls in `libs/client/src/state/Client__State__StateReducer.res` away from `credentials: Include`.
- Custom-provider fetch now uses `Client__EmbeddedAuth.headers()`.
- Custom-provider save and update now use `Client__EmbeddedAuth.jsonHeaders()`.
- Custom-provider delete now uses `Client__EmbeddedAuth.headers()`.
- On missing embedded token, custom-provider fetch requests shared authentication through `requireAuthentication()`.
- On custom-provider fetch `401`, the embedded token is cleared and shared authentication is requested.
- On missing embedded token or `401`, custom-provider mutations request shared authentication and dispatch `CustomProviderMutationFailed` with `CustomProviderNetworkError("Frontman authorization is required")`.
- Updated test fixtures to include the new `requireAuthentication` callback on `AcpSessionActive`.
- Added reducer coverage for missing custom-provider auth requesting the shared auth flow.
- Updated SettingsModal interaction tests to seed an embedded token when exercising custom-provider mutation fetches.

Implementation files:

- `libs/client/src/Client__App.res`
- `libs/client/src/Client__ConnectionReducer.res`
- `libs/client/src/Client__FrontmanProvider.res`
- `libs/client/src/state/Client__State.res`
- `libs/client/src/state/Client__State__Types.res`
- `libs/client/src/state/Client__State__StateReducer.res`
- `libs/client/test/Client__State__StateReducer.test.res`
- `libs/client/test/Client__SettingsModal.interaction.test.mjs`
- `libs/client/test/Client__ModelsRefresh.test.res`

Verification completed:

```bash
cd libs/client && make build
cd libs/client && make test
cd libs/client && yarn rescript format -c src/Client__App.res src/Client__ConnectionReducer.res src/Client__FrontmanProvider.res src/state/Client__State.res src/state/Client__State__Types.res src/state/Client__State__StateReducer.res test/Client__State__StateReducer.test.res test/Client__ModelsRefresh.test.res
rg "credentials: Include" libs/client/src/state/Client__State__StateReducer.res
```

`make build` and `make test` passed. The focused ReScript format check passed.

Known unrelated verification note:

- `cd libs/client && make lint` still fails on pre-existing unrelated formatting issues in:
  - `libs/client/src/styles/frontman-theme.css`
  - `libs/client/test/Client__Task__AnnotationEnrichment.test.mjs`

#### Slice 2.5: Popup Login Lifecycle — DONE

Implemented:

- Added `libs/client/src/Client__EmbeddedAuthPopup.res` for popup authorization lifecycle.
- Generated 32 random bytes of authorization state with Web Crypto and encoded it as 64 hex characters.
- Added embedded authorization URL construction with `embedded_state` and `embedded_origin` parameters.
- Opened a named popup instead of relying on `_blank`/`noopener` links.
- Validated popup completion messages by Frontman origin, popup source, versioned message type, and state.
- Saved the returned token through `Client__EmbeddedAuth.saveToken` only after all validation passes.
- Cleaned up message listeners and timers after success, timeout, popup closure, error, repeated sign-in, or component unmount.
- Reused `Client__WelcomeModal` and the existing `beginAuthenticationRetry` path instead of adding a new auth UI.
- Added focused tests for URL construction, 256-bit state length, valid completion messages, wrong origin, wrong source, and wrong state.

Implementation files:

- `libs/bindings/src/Bindings__WebAPI.res`
- `libs/client/src/Client__EmbeddedAuthPopup.res`
- `libs/client/src/Client__WelcomeModal.res`
- `libs/client/test/Client__EmbeddedAuthPopup.test.res`

Verification completed:

```bash
cd libs/client && yarn rescript format -c ../bindings/src/Bindings__WebAPI.res src/Client__EmbeddedAuthPopup.res src/Client__WelcomeModal.res test/Client__EmbeddedAuthPopup.test.res
cd libs/client && make build
cd libs/client && make test
```

#### Slice 3: OAuth Endpoint Migration And Public Update Check Cleanup — DONE

Implemented:

- Migrated Anthropic OAuth status, authorize-url, exchange, and disconnect calls away from `credentials: Include`.
- Migrated OpenAI OAuth status, initiate, poll, and disconnect calls away from `credentials: Include`.
- OAuth HTTP calls now use `Client__EmbeddedAuth.headers()` or `Client__EmbeddedAuth.jsonHeaders()`.
- Missing embedded tokens and OAuth `401` responses now clear/request embedded authentication through the shared `requireAuthentication()` path.
- Preserved existing Anthropic PKCE and OpenAI device-code behavior.
- Removed the now-unused reducer-local JSON-only header helper.
- Classified `/api/integrations/latest-versions` as public because the server router keeps it under `:api`, not `:bearer_api`; removed `credentials: Include` from that fetch instead of adding auth.
- Added reducer coverage proving all OAuth effects request shared authentication when the embedded token is missing.

Implementation files:

- `libs/client/src/state/Client__State__StateReducer.res`
- `libs/client/test/Client__State__StateReducer.test.res`

Verification completed:

```bash
cd libs/client && make build
cd libs/client && make test
cd libs/client && yarn rescript format -c src/state/Client__State__StateReducer.res test/Client__State__StateReducer.test.res
cd libs/client && rg -n "credentials: Include" src
```

Step 5 removed the legacy `Client__ConnectionReducer.res` `credentials: Include` logout/session probe and stale `tokenUrl` plumbing.

### Goal

Stop using `credentials: Include` for protected central APIs. Store and use the embedded bearer token from the approved customer origin.

### Scope

Add ReScript client credential primitives:

- localStorage key
- load token
- save token
- clear token
- build `Authorization` header

Add popup login lifecycle:

- generate at least 256 bits of cryptographically random state
- open the Frontman login popup
- pass state and current customer origin
- validate `event.origin` equals configured Frontman origin
- validate `event.source` equals the opened popup
- validate versioned message type
- validate returned state
- remove listeners after success, failure, timeout, popup closure, or component cleanup

Migrate protected API calls in `Client__State__StateReducer.res` to bearer auth:

- profile
- API keys
- custom providers
- Anthropic OAuth endpoints
- OpenAI OAuth endpoints

On `401`, clear the token and require reauthorization.

### Existing Code To Read First

- `libs/client/src/Main.res`
- `libs/client/src/state/Client__State__StateReducer.res`
- `libs/client/src/Client__ConnectionReducer.res`
- `libs/client/src/Client__FrontmanProvider.res`
- tests under `libs/client/test/`

### Cleanup While Touching

- All API calls and side effects must stay in the StateReducer unless explicitly justified.
- Centralize authenticated fetch/header construction instead of repeating it.
- Remove migrated `credentials: Include` calls.
- Prefer typed ReScript bindings and externals over `%raw` JavaScript.
- Prefer `switch` over `if/else` for control flow.

### Suggested PR Split

Split into small PRs:

1. credential storage/header helper + tests — DONE
2. popup lifecycle + tests — DONE
3. profile and API-key fetch migration — DONE
4. custom provider fetch migration — DONE
5. OAuth endpoint fetch migration — DONE

Each PR must stay below 500 changed lines.

### Verification

```bash
cd libs/client && make test
cd libs/client && make build
rg "credentials: Include" libs/client/src
```

The `rg` command should show only unmigrated call sites expected for later PRs, or no results after this step is complete.

## Step 5: Migrate Sockets, Remove Legacy Paths, Harden CORS — DONE

### Status

Implemented in this working tree:

- Added Phoenix JS `authToken` support to the ReScript socket binding.
- Removed the client `/api/socket-token` fetch and socket token query-param path.
- Removed `tokenUrl` client config plumbing.
- Socket connections now use the embedded client token from `localStorage` through `authToken`.
- Missing embedded tokens now use the existing shared authentication-required flow.
- Logout now revokes `DELETE /api/client-token`, clears the embedded token, disconnects sockets, and reloads.
- `UserSocket` now verifies Phoenix `auth_token` with embedded client token lookup.
- Removed session fallback from `/socket` and rejects unauthorized socket connections.
- Assigned `scope` and `embedded_client_token_id` to authorized sockets.
- Added token-specific socket ids as `client_token:<id>`.
- Added authenticated `DELETE /api/client-token` revocation endpoint.
- Revocation deletes the exact token record and broadcasts socket disconnect to the token-specific socket id.
- Removed `/api/socket-token` route and deleted `SocketTokenController`.
- Hardened API CORS to wildcard origin, `authorization, content-type` allowed headers, and no credentials.
- Removed reflected-origin CORS behavior.

Implementation files:

- `libs/frontman-client/src/FrontmanClient__Phoenix__Socket.res`
- `libs/frontman-client/src/FrontmanClient__ACP.res`
- `libs/client/src/Client__ConnectionReducer.res`
- `libs/client/src/Client__FrontmanProvider.res`
- `libs/client/src/Main.res`
- `libs/client/test/Client__ConnectionReducer.test.res`
- `apps/frontman_server/lib/frontman_server_web/channels/user_socket.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/client_token_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/endpoint.ex`
- `apps/frontman_server/lib/frontman_server_web/plugs/cors.ex`
- `apps/frontman_server/lib/frontman_server_web/router.ex`
- `apps/frontman_server/test/frontman_server_web/channels/user_socket_test.exs`
- `apps/frontman_server/test/frontman_server_web/controllers/client_token_controller_test.exs`
- `apps/frontman_server/test/frontman_server_web/plugs/cors_test.exs`

Removed files:

- `apps/frontman_server/lib/frontman_server_web/controllers/socket_token_controller.ex`

Verification completed:

```bash
cd libs/frontman-client && make test
cd libs/client && make build
cd libs/client && make test
cd apps/frontman_server && mix test test/frontman_server_web/channels/user_socket_test.exs test/frontman_server_web/controllers/client_token_controller_test.exs test/frontman_server_web/plugs/cors_test.exs test/frontman_server_web/channels
cd apps/frontman_server && mix format --check-formatted
cd apps/frontman_server && mix compile --warnings-as-errors --all-warnings
rg "credentials: Include|socket-token|SocketTokenController|api_with_session|allow-credentials|tokenUrl"
```

The final `rg` has no active production references. The only match is a CORS test assertion proving `access-control-allow-credentials` is absent.

### Goal

Complete the security cutover by removing the session-cookie socket path, deleting socket-token minting, and removing credentialed CORS.

### Scope

Client socket migration:

- update Phoenix JS/ReScript binding to use `authToken`
- stop fetching `/api/socket-token`
- stop passing socket token through params
- remove stale `tokenUrl` config once unused

Server socket migration:

- update `FrontmanServerWeb.UserSocket`
- verify embedded-client token from Phoenix `authToken`
- remove session fallback
- reject unauthorized socket connections
- assign `current_scope`
- assign embedded token record ID
- set socket id to `client_token:<id>` or equivalent

Revocation and logout:

- add `DELETE /api/client-token`
- authenticate it with the embedded bearer token
- delete the exact token record
- broadcast disconnect to the token-specific socket id
- ensure revoked tokens cannot reconnect

Legacy removal:

- remove `/api/socket-token` route
- remove `SocketTokenController`
- remove socket-token tests
- remove remaining client references to `socket-token` and `tokenUrl`

CORS hardening:

- change API CORS to `Access-Control-Allow-Origin: *`
- allow `authorization, content-type`
- remove `Access-Control-Allow-Credentials`
- remove reflected-origin behavior unless still needed for a non-embedded route and documented

### Existing Code To Read First

- `libs/frontman-client/src/FrontmanClient__ACP.res`
- Phoenix client binding modules used by `Socket.make`
- `libs/client/src/Client__ConnectionReducer.res`
- `libs/client/src/Main.res`
- `apps/frontman_server/lib/frontman_server_web/channels/user_socket.ex`
- `apps/frontman_server/lib/frontman_server_web/controllers/socket_token_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/plugs/cors.ex`
- `apps/frontman_server/lib/frontman_server_web/router.ex`
- channel tests under `apps/frontman_server/test/frontman_server_web/channels/`
- CORS tests at `apps/frontman_server/test/frontman_server_web/plugs/cors_test.exs`

### Cleanup While Touching

- Remove `/socket` session `connect_info` if it is no longer needed.
- Keep `/live` session `connect_info` for LiveView.
- Remove now-empty `:api_with_session` if it still exists.
- Ensure tokens are never sent in WebSocket query parameters.
- Ensure unauthorized sockets are rejected instead of accepted anonymously.

### Suggested PR Split

Split into small PRs:

1. client Phoenix socket `authToken` support
2. server socket bearer authentication
3. revocation endpoint + socket disconnect
4. remove `/api/socket-token` and stale client config
5. CORS hardening
6. final regression tests/docs/changelog

Each PR must stay below 500 changed lines.

### Verification

```bash
cd libs/frontman-client && make test
cd libs/client && make test
cd apps/frontman_server && mix test test/frontman_server_web/channels
cd apps/frontman_server && mix test test/frontman_server_web/plugs/cors_test.exs
rg "credentials: Include|socket-token|SocketTokenController|api_with_session|allow-credentials|tokenUrl"
```

After final cutover, the `rg` command should return no active production references. Test or historical documentation references are allowed only if intentional and clearly named as legacy coverage.

## Final Acceptance Criteria

- Hostile origin cannot read protected resources through a Frontman session cookie.
- Hostile origin cannot mutate protected resources through a Frontman session cookie.
- Valid Frontman session cookie without embedded bearer token returns `401` on protected embedded APIs.
- Embedded clients do not use `credentials: Include` for protected central APIs.
- User does not repeatedly authenticate during normal use.
- Client authorization persists per browser and customer origin.
- Popup validates state, message origin, and popup source.
- Consent displays the exact normalized customer origin.
- Token is random, opaque, hash-only at rest, expiring, and individually revocable.
- HTTP and WebSocket use the same embedded client authorization.
- Token revocation disconnects active WebSocket.
- Socket session fallback and `/api/socket-token` endpoint are removed.
- Tokens never appear in URLs, logs, telemetry, or error responses.
- API CORS does not allow credentials.
- Safari and WebKit authentication do not depend on third-party cookies.

## Decisions Made During Implementation

- Initial embedded-client token lifetime is 90 days.
- Expiration is absolute. `last_used_at` is tracked for audit/management, not sliding renewal.
- Active authorization management UI is follow-up work; this cut revokes the current token on logout.
- Cutover is hard: protected HTTP APIs and sockets require embedded bearer tokens with no session fallback.

## Final Cleanup Completed

- Removed the unrelated `mise.toml` `pi = "latest"` change from the working tree.
- Moved popup completion behavior out of an inline HEEx `<script>` and into the existing `app.js` bundle.
- Confirmed stale-reference search has no active production matches for `credentials: Include`, `socket-token`, `SocketTokenController`, `api_with_session`, `allow-credentials`, or `tokenUrl`.
