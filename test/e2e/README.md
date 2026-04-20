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

## Secrets

Copy `test/e2e/.env.example` to `test/e2e/.env` and populate:

- `E2E_CHATGPT_ACCESS_TOKEN`
- `E2E_CHATGPT_REFRESH_TOKEN`
- `E2E_CHATGPT_ACCOUNT_ID`

Local run:

```bash
make e2e
```
