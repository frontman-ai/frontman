# Frontman E2E Environment Contract

`test/e2e/global-setup.ts` always boots the Phoenix app with `MIX_ENV=e2e`.

## Server environment

- Config file: `apps/frontman_server/config/e2e.exs`
- HTTPS endpoint: `https://localhost:4002`
- Default database: `frontman_server_e2e`
- No code reloader/watchers/live reload

## Runtime overrides

`apps/frontman_server/config/runtime.exs` supports these overrides in `:e2e`:

- `DB_HOST` (default: `localhost`)
- `DB_NAME` (default comes from `config/e2e.exs`)
- `PHX_SERVER` (default: `false`)

Boolean env vars use one canonical parser in both Elixir and TS setup code.

- Truthy: `1`, `true`, `yes`, `on`
- Falsy: `0`, `false`, `no`, `off`
- Empty/unset: use default
- Any other value: raises immediately

## Certificate trust

Run `make ssl-setup` before the local E2E suite.
The Makefile exports the mkcert CA path through `NODE_EXTRA_CA_CERTS` before Node starts.
To use another test CA, set `NODE_EXTRA_CA_CERTS` to its readable PEM file.
The launcher stops if the CA file is missing.
Certificate validation remains enabled.

## Secrets

Copy `test/e2e/.env.example` to `test/e2e/.env` and populate:

- `E2E_OPENAI_ACCESS_TOKEN`
- `E2E_OPENAI_REFRESH_TOKEN`
- `E2E_OPENAI_ACCOUNT_ID`

The suite also requires the development WorkOS API key and client ID as resolved
`WORKOS_API_KEY` and `WORKOS_CLIENT_ID` process environment variables. The
server's `apps/frontman_server/envs/.dev.secrets.env` contains 1Password
references for these values. For example, after signing in to 1Password:

```bash
op run --env-file=apps/frontman_server/envs/.dev.secrets.env -- make e2e
```

The WorkOS process values take precedence over `test/e2e/.env`. Do not use
production credentials. CI uses the repository Actions secret
`E2E_WORKOS_API_KEY` and variable `E2E_WORKOS_CLIENT_ID` for the E2E step.
Fork pull requests without access to the secret fail rather than skip this test.
Only run credential-bearing workflows on trusted code.

The WorkOS MCP test uses synthetic users in the development environment. A full
run retains two public clients and three provider users. It also changes the email
of one synthetic provider user. The test removes its local users and logs public
client IDs and provider IDs when available. Early failures can leave unreported
provider IDs. It does not delete provider accounts or modify provider configuration.

Local run:

```bash
make e2e
```

## OpenAI preflight and credential recovery

PR E2E reads credentials but never rotates the shared refresh grant or writes repository secrets.
The scheduled/manual **Refresh E2E OpenAI token** workflow is the only rotation owner.
It runs on the default branch with the Actions-only `E2E_SECRET_ROTATION_GH_TOKEN`.
Do not add that privileged token to Dependabot secrets or expose it to PR code.

The owner refreshes near-expiry tokens and persists each rotated pair before the provider preflight.
The preflight also runs when the JWT expiration is in the future.
An unexpired JWT does not prove that OpenAI still accepts the token.
After an explicit authentication rejection, the owner refreshes once, persists again, and retries the preflight once.
Rate limits, network errors, model permission errors, and server errors do not trigger authentication recovery.
Browser tests never retry as part of credential recovery.

The preflight uses ReqLLM's Codex streaming transport and the same OAuth account options as `Providers.resolve_model_access`.
It selects the first Codex model from `config/providers.exs`, as fresh E2E browser sessions do.
It requests only `OK`, uses no tools, and closes the stream after the first content chunk.
The request has a 30-second total timeout, a 15-second idle timeout, and a 64-chunk consumption limit.
Codex does not accept an output-token cap through this transport.
Early cancellation bounds consumption but does not guarantee a specific provider charge.
Raw provider errors and generated text do not appear in preflight logs.

### Recover the current incident

1. Run **Refresh E2E OpenAI token** on the default branch with `force_refresh=true`.
2. Check that persistence and the model preflight both succeed.
3. If refresh or authentication fails again, reconnect the E2E account through the normal OpenAI OAuth flow.
4. Replace `E2E_CHATGPT_ACCESS_TOKEN`, `E2E_CHATGPT_REFRESH_TOKEN`, and `E2E_CHATGPT_ACCOUNT_ID` in both Actions and Dependabot secrets.
5. Run the trusted workflow again to check model access.
6. Start a new E2E run after recovery.

Keep credentials out of logs, artifacts, patches, and command history.
The code change alone cannot restore a revoked refresh grant.
Do not repeat refresh blindly after a persistence error.
Secret writes across the credential pair and the two GitHub secret stores are not atomic.
A partial write or interrupted rotation can require manual replacement of the complete pair.

The owner uses a non-cancelling concurrency queue to prevent overlapping workflow writers.
This does not guarantee that queued jobs receive the newest secret values.
GitHub can snapshot secrets before a queued job starts.
PR readers can also overlap rotation and use an older token.
After rotation, start a new run with current credentials.
There is no evidence that concurrent rotation caused the original revocation.

### Validate without credentials

```bash
make -C apps/frontman_server test-e2e-openai-auth
make -C apps/frontman_server check-e2e-openai-auth
```

The focused suite uses the real ReqLLM error normalizer, SSE decoder, model catalog, and transport request builder.
It makes no HTTP calls and does not load the normal test helper's mock setup.
Pure decision tests cover forced refresh and authentication classification.
Live revocation cannot be induced safely in this suite.
The suite therefore cannot prove that the current credential pair works or that GitHub secret persistence succeeds.

### Validate live model access

With approved E2E credentials already in the process environment, run:

```bash
make -C apps/frontman_server e2e-openai-preflight
```

This command makes a small authenticated provider request.
It does not refresh credentials.
Missing credentials, authentication rejection, and other provider errors fail before browser tests in CI.
PR CI also requires more than 30 minutes of token lifetime to avoid expiry-driven refresh during browser tests.
For full validation after recovery, run `make e2e`.
