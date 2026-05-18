# FrontmanServer

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`frontman.local:4000`](https://frontman.local:4000) from your browser.

## Local Stripe webhooks

Stripe cannot call `localhost` directly. Use the Stripe CLI listener to create a temporary tunnel and forward events to Phoenix.

Install repo tools from the monorepo root:

```bash
make install
```

Log in to Stripe once:

```bash
mise exec -- stripe login
```

Start webhook forwarding:

```bash
make stripe-webhooks
```

The listener forwards to Phoenix at `https://localhost:4000/api/stripe/webhook`, passes `--skip-verify` for the local HTTPS certificate, captures the CLI signing secret, masks it in logs, and writes it to `envs/.dev.stripe-webhook.env` as `STRIPE_WEBHOOK_SECRET`. `config/runtime.exs` loads that into `Application.fetch_env!(:frontman_server, :stripe)[:webhook_secret]` at Phoenix boot. Use a test-mode API key like `sk_test_...` for `STRIPE_SECRET_KEY`.

Forwarded events:

```text
checkout.session.completed
customer.subscription.created
customer.subscription.updated
customer.subscription.deleted
customer.subscription.paused
customer.subscription.resumed
```

`make dev` starts this listener in mprocs as `stripe-webhooks`; the server waits for the generated `STRIPE_WEBHOOK_SECRET` before booting. Keep Stripe CLI login completed, or provide a test `STRIPE_SECRET_KEY` so the script can pass it to Stripe CLI as `STRIPE_API_KEY`.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Architecture docs

* Boundary contract policy: [`BOUNDARY_CONTRACT_POLICY.md`](./BOUNDARY_CONTRACT_POLICY.md)

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
