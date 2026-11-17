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
