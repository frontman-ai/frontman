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

Local run:

```bash
make e2e
```

## Real signup and billing

The full suite includes hosted WorkOS Test SSO and real Stripe sandbox Checkout.
This scenario does not use the seeded account or inject a subscription.

1. Enable SSO in a dedicated WorkOS staging environment.
2. Register `https://localhost:4002/auth/callback` as an application redirect URI.
3. Copy the hosted Test SSO connection ID from the WorkOS dashboard.
4. Enable Managed Payments in the Stripe sandbox.
5. Configure active monthly and yearly recurring prices in that sandbox.
6. Add these variables to `test/e2e/.env` locally, or GitHub Actions secrets with the same names:

- `E2E_WORKOS_API_KEY` (staging key)
- `E2E_WORKOS_CLIENT_ID`
- `E2E_WORKOS_CONNECTION_ID`
- `E2E_STRIPE_SECRET_KEY` (test key)
- `E2E_STRIPE_MONTHLY_PRICE_ID`
- `E2E_STRIPE_YEARLY_PRICE_ID`

Run `make e2e-signup-billing` for this scenario alone.
Run `make e2e-check` for type checks and credential/cleanup safety tests.
Existing focused framework targets do not require these new credentials.
CI uses the same environment-variable mechanism as the existing ChatGPT tests.
No 1Password integration is required.

The setup starts the installed Stripe CLI and captures its webhook signing secret.
The server still verifies signatures. The CLI accepts the local development certificate.
Test SSO access is available only in the E2E environment.

Each run uses a fresh database and a unique `frontman-e2e-<uuid>@example.com` identity.
Cleanup deletes the WorkOS user and Stripe customer, cancels subscriptions, and expires open Checkout Sessions.
Cleanup also stops process groups, restores fixtures, and deletes the run database.
Cleanup failures fail the suite. Stripe retains completed session and event history.
CI also performs its existing process and database cleanup after failures.

This scenario proves SSO signup and trial activation, not Google/GitHub provider configuration or a charge after the trial.
Missing credentials fail the full suite rather than skip this critical path.
