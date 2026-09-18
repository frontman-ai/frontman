# Frontman E2E Environment Contract

Both suites use Vitest and Playwright through `vitest.config.ts`.

- `integration`: real framework fixtures, Phoenix, authentication, and AI prompt tests. Run with `make e2e`.
- `browser`: same-origin preview lifecycle and cross-origin rejection in Chromium, Firefox, and WebKit. Run with `make e2e-browser`. No server credentials are required.

The browser suite runs shared scenarios once per browser through the production transport, with intercepted pages and packaged WordPress assets.
It does not run WordPress. `make test-wordpress-preview` checks WordPress authorization and enqueue behavior with PHP stubs.
The framework E2Es check page context through real Astro, Vite, and Next.js installations.
Client unit tests cover metadata conversion, originating-task capture, and missing or failed context requests.

Install the browser engines and system libraries before the first browser run:

```bash
make e2e-install-browser-deps e2e-install-browsers
make e2e-browser
```

To select an engine or test, use the Vitest filter:

```bash
make e2e-browser E2E_ARGS='-t Firefox'
```

The integration suite uses `global-setup.ts` to start Phoenix with `MIX_ENV=e2e`.

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

- `E2E_OPENAI_ACCESS_TOKEN`
- `E2E_OPENAI_REFRESH_TOKEN`
- `E2E_OPENAI_ACCOUNT_ID`

Local run:

```bash
make e2e
```
