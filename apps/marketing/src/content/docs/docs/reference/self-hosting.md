---
title: Self-Host the Frontman Server
description: Build, configure, migrate, and verify your own Frontman orchestration server using repository-supported deployment paths.
---

Self-hosting runs Frontman's Phoenix orchestration server and PostgreSQL persistence in your infrastructure. It does not replace the framework integration in your app or the browser client that executes preview tools.

This page owns server deployment. [Architecture Overview](/docs/reference/architecture/) owns component and data flow, [Configuration Options](/docs/reference/configuration/) owns framework integration settings, and [Configure Frontman API Keys & Providers](/docs/api-keys/) owns per-account model credentials.

:::caution[Review licensing before deployment]
The server under `apps/frontman_server/` is licensed under AGPL-3.0-only with the repository's [AI Supplementary Terms](https://github.com/frontman-ai/frontman/blob/main/AI-SUPPLEMENTARY-TERMS.md). Client and JavaScript framework libraries use Apache-2.0, while the WordPress plugin uses GPL-2.0-or-later. Review the actual license files for your use case; this page is not legal advice.
:::

## What self-hosting changes

With hosted Frontman, `api.frontman.sh` orchestrates the agent loop and stores account and task data. With self-hosting, your server deployment performs those jobs.

Self-hosting does **not** move every operation into the Phoenix container:

- Browser tools still run in the user's Frontman browser session.
- File tools still run through the framework integration on the machine serving the development app.
- Relevant prompts, file content, screenshots, logs, metadata, tool results, and generated output can pass through your Frontman server to the selected LLM provider.
- Users still need model access through a supported OAuth connection or saved API key.

The server has no direct access to the user's project filesystem. See [Architecture Overview](/docs/reference/architecture/) for the request and tool relay.

## Requirements

Choose infrastructure that provides:

- A PostgreSQL database reachable by the Frontman server
- An HTTPS endpoint with WebSocket support
- GitHub and Google sign-in configured through WorkOS for production users
- Outbound HTTPS access to WorkOS, whichever LLM providers users connect, and the built-in Sentry endpoint unless you modify the server source
- Persistent PostgreSQL backups appropriate for your environment

The repository's production image builds with Elixir 1.20, Erlang/OTP 29, and Node.js 24, then runs on Debian Bookworm without build tools. If you use the supplied Dockerfile, those build versions are already defined in the image.

No repository source establishes universal CPU, memory, disk, user-capacity, monthly-storage, uptime, or cost requirements. Size and monitor your deployment from observed workload rather than using fixed estimates.

## Required production configuration

The production runtime reads these values:

| Variable           | Purpose                                                                |
| ------------------ | ---------------------------------------------------------------------- |
| `DATABASE_URL`     | PostgreSQL connection string, such as `ecto://user:pass@host/database` |
| `SECRET_KEY_BASE`  | Phoenix cookie and application secret                                  |
| `CLOAK_KEY`        | Key used by Cloak for stored provider credentials                      |
| `WORKOS_API_KEY`   | WorkOS API credential for hosted sign-in                               |
| `WORKOS_CLIENT_ID` | WorkOS client ID                                                       |
| `PHX_HOST`         | Public hostname used in generated server URLs                          |
| `PHX_SERVER=true`  | Starts the Phoenix HTTP endpoint outside the supplied image            |

Common deployment settings:

| Variable                        | Default              | Purpose                                                          |
| ------------------------------- | -------------------- | ---------------------------------------------------------------- |
| `PORT`                          | `4000`               | HTTP port inside the runtime                                     |
| `DATABASE_SSL`                  | `true` in production | Set `false` only when the database connection should not use SSL |
| `POOL_SIZE`                     | `10`                 | Ecto database connection pool size                               |
| `ECTO_IPV6`                     | `false`              | Enables IPv6 socket options when set to a supported true value   |
| `DNS_CLUSTER_QUERY`             | unset                | DNS query used by the included cluster configuration             |
| `RESEND_API_KEY`                | unset                | Enables welcome-email and contact-sync workers when non-empty    |
| `DISCORD_NEW_USERS_WEBHOOK_URL` | unset                | Enables new-user notification worker when non-empty              |

Generate `SECRET_KEY_BASE` with `mix phx.gen.secret`. The repository environment template uses `openssl rand -base64 32` for `CLOAK_KEY`. Store both outside source control. Changing `CLOAK_KEY` without a credential migration prevents existing encrypted provider credentials from being decrypted.

Production registration is disabled; users sign in through configured OAuth providers. Configure matching callback and redirect URLs in WorkOS before testing sign-in.

## Built-in telemetry egress

Self-hosting does not make the supplied source telemetry-free:

- In production, [`config/runtime.exs`](https://github.com/frontman-ai/frontman/blob/main/apps/frontman_server/config/runtime.exs) assigns the server Sentry DSN directly to Frontman's `o4510512511320064.ingest.de.sentry.io` project. Server exceptions and reported errors can therefore leave the deployment for that Sentry project. The runtime source does not read a Sentry DSN or disable flag from the environment.
- The browser client calls `Client__Heap.init()` at startup. [`Client__Heap.res`](https://github.com/frontman-ai/frontman/blob/main/libs/client/src/Client__Heap.res) loads `https://cdn.us.heap-api.com/config/<env-id>/heap_config.js` and uses Heap environment `349428408` when `import.meta.env.DEV` is true (or unavailable, because [`Client__Env.isDev`](https://github.com/frontman-ai/frontman/blob/main/libs/client/src/Client__Env.res) falls back to `true`) and `218974947` in a production Vite build. The source provides no runtime setting to replace the Heap environment or disable initialization.

The documented environment variables cannot disable either integration. If policy forbids this egress, modify and rebuild the relevant server/client source before deployment and enforce outbound network policy as defense in depth. Blocking the destinations without rebuilding can produce failed telemetry requests in server or browser logs; it is not a supported disable control.

## Deploy with Railway

The repository root includes `railway.json`. It points Railway at `apps/frontman_server/Dockerfile`, runs database migrations before deployment, checks `/health`, and restarts the service on failure.

1. Create a Railway project from the Frontman repository.
2. Add a PostgreSQL service.
3. Configure the Frontman service with `apps/frontman_server/Dockerfile` if Railway does not apply `railway.json` automatically.
4. Set the required production variables above, using Railway references for the public hostname and PostgreSQL URL where appropriate.
5. Deploy and inspect the pre-deploy migration and health-check results.
6. Open `/health/ready` to verify that the running application can query PostgreSQL.

Railway is one supported configuration path, not a published one-click template in this repository.

## Deploy with Docker

Build from the repository root so the Dockerfile can copy monorepo workspaces:

```bash
docker build -f apps/frontman_server/Dockerfile -t frontman-server .
```

Run the image with production variables supplied by your deployment system:

```bash
docker run --rm \
  --name frontman-server \
  -p 127.0.0.1:4000:4000 \
  -e DATABASE_URL='ecto://user:pass@postgres-host/frontman_server_prod' \
  -e DATABASE_SSL=false \
  -e PHX_HOST='frontman.example.com' \
  -e SECRET_KEY_BASE='<generated-secret>' \
  -e CLOAK_KEY='<generated-key>' \
  -e WORKOS_API_KEY='<workos-api-key>' \
  -e WORKOS_CLIENT_ID='<workos-client-id>' \
  frontman-server
```

The example publishes the container port only on host loopback. Put a TLS-terminating reverse proxy with WebSocket support in front of it, and restrict proxy and host-network access to intended users and networks. Do not publish port 4000 on every host interface. The database hostname and TLS setting are placeholders; use a hostname reachable from the container, and set `DATABASE_SSL` to match that database.

Run migrations against the same environment before directing users to a new release:

```bash
docker run --rm \
  -e DATABASE_URL='ecto://user:pass@postgres-host/frontman_server_prod' \
  -e DATABASE_SSL=false \
  -e SECRET_KEY_BASE='<generated-secret>' \
  -e CLOAK_KEY='<generated-key>' \
  -e WORKOS_API_KEY='<workos-api-key>' \
  -e WORKOS_CLIENT_ID='<workos-client-id>' \
  frontman-server \
  /app/bin/frontman_server eval "FrontmanServer.Release.migrate()"
```

How the database hostname resolves depends on your Docker network or hosting platform. The repository does not provide a complete Docker Compose production stack.

## Deploy with repository VM scripts

`infra/production/` contains the scripts used for Frontman's VM deployment layout:

- `server-setup.sh` installs PostgreSQL, Caddy, systemd units, firewall rules, fail2ban, and a daily database-backup cron.
- `deploy.sh` deploys a release tarball to the inactive blue/green slot, runs migrations, checks health, and changes the Caddy upstream.
- `rollback.sh` checks the previous slot before changing Caddy back to it.
- `backup-pg.sh` writes daily PostgreSQL dumps and prunes backups according to the script's configured retention.

These scripts assume their documented Ubuntu host layout, paths under `/opt/frontman`, privileged package installation, and local PostgreSQL. Read and adapt them before running them on an existing server. Their presence does not establish an uptime or recovery-time guarantee.

## Run from source for development

Repository development uses Elixir 1.20, Node.js 24, Yarn, and PostgreSQL. From the repository root:

```bash
yarn install
cd apps/frontman_server
make setup
make dev
```

The server Makefile starts Phoenix through `op run` and `envs/.dev.secrets.env`, whose values are 1Password `op://` references. If you do not use that workflow, supply required application secrets through your process environment and run the appropriate Mix server command directly.

Development environment files load in this order, with later values taking precedence:

1. `envs/.env`
2. `envs/.dev.env`
3. `envs/.dev.overrides.env`
4. Process environment variables

This source path is for development. Use a release image or release tarball for production.

## Connect an app to your server

Set the framework integration's `host` option or `FRONTMAN_HOST` to your server hostname. Restart the app's development server, open `/frontman`, and complete sign-in against your deployment.

Do not change `clientUrl`, `clientCssUrl`, or `entrypointUrl` unless your deployment serves those assets or endpoints from custom locations. [Configuration Options](/docs/reference/configuration/) owns those integration settings.

## Verify a deployment

1. Request `GET /health`; it should return `{"status":"ok"}` when the application process is serving requests.
2. Request `GET /health/ready`; it should return `{"status":"ready","database":"connected"}` when PostgreSQL is reachable.
3. Open the server root and complete GitHub or Google sign-in.
4. Point a supported framework integration at the server and open `/frontman` in the development app.
5. Connect a model provider, send a small prompt, and confirm browser and file tool calls return through the integration.
6. Restart the browser session and confirm task history can be loaded from PostgreSQL.

Health endpoints prove process and database readiness only. They do not test WorkOS, provider credentials, browser tools, file relay, backups, or external LLM availability.

## Updates and rollback

Before updating:

1. Read the repository [changelog](https://github.com/frontman-ai/frontman/blob/main/CHANGELOG.md).
2. Back up PostgreSQL and verify that the backup can be restored in your environment.
3. Build the target commit or image.
4. Run `FrontmanServer.Release.migrate()` with the new release environment.
5. Check `/health/ready`, sign-in, and one end-to-end agent task before completing rollout.

Database migrations do not imply automatic downgrade compatibility. Use the supplied rollback script only with the VM layout it expects, and review migrations before attempting an application or database rollback.

## Security boundaries

- Terminate HTTPS in front of production HTTP and WebSocket traffic.
- Restrict inbound access at the reverse proxy, firewall, private network, or identity-aware access layer. The production endpoint binds all interfaces inside its runtime, and the Docker example relies on host-loopback publishing to keep that HTTP listener off external interfaces.
- Production [`runtime.exs`](https://github.com/frontman-ai/frontman/blob/main/apps/frontman_server/config/runtime.exs) hard-codes Phoenix `check_origin: false`. This disables Phoenix socket Origin validation; it does not mean “same origin only.” There is no environment variable in current source to enable or configure allowed origins. Treat authentication, TLS, and network access controls as required, and modify the endpoint configuration if your threat model requires socket Origin enforcement.
- Protect `SECRET_KEY_BASE`, `CLOAK_KEY`, WorkOS credentials, database credentials, and optional integration secrets outside source control.
- Back up PostgreSQL; it stores users, task history, OAuth records, and encrypted provider credentials.
- The `CLOAK_KEY` protects stored provider credentials at the application layer. Database encryption does not remove the need to protect that key and restrict server access.
- Self-hosting controls the orchestration and persistence environment. It does not prevent data from reaching a user-selected LLM provider.

Review [Frontman Limitations & Workarounds](/docs/using/limitations/) for client and tool boundaries and the [Privacy Policy](/privacy/) for hosted-service data handling.

## Troubleshooting

**The container exits during startup.**
Check logs for a missing `DATABASE_URL`, `SECRET_KEY_BASE`, or `CLOAK_KEY`, an invalid boolean environment value, or database connection failure.

**`/health` works but `/health/ready` returns 503.**
The application is running but its `SELECT 1` database check failed. Verify database hostname, credentials, network access, and `DATABASE_SSL`.

**Users cannot sign in.**
Verify WorkOS API credentials and callback/redirect configuration for the public `PHX_HOST`. Production does not expose public registration as an alternative.

**The app's `/frontman` still uses the hosted server.**
Set `host` or `FRONTMAN_HOST` in the framework integration and restart the app's development server.

**A provider model is unavailable.**
Provider access is configured per Frontman account. Follow [Configure Frontman API Keys & Providers](/docs/api-keys/) on the self-hosted instance.

For non-deployment failures, continue with [Troubleshooting](/docs/reference/troubleshooting/).

## Repository references

- [Frontman server Dockerfile](https://github.com/frontman-ai/frontman/blob/main/apps/frontman_server/Dockerfile)
- [Railway configuration](https://github.com/frontman-ai/frontman/blob/main/railway.json)
- [Production scripts](https://github.com/frontman-ai/frontman/tree/main/infra/production)
- [Production environment template](https://github.com/frontman-ai/frontman/blob/main/infra/production/env.template)
- [Server license](https://github.com/frontman-ai/frontman/blob/main/apps/frontman_server/LICENSE)
- [AI Supplementary Terms](https://github.com/frontman-ai/frontman/blob/main/AI-SUPPLEMENTARY-TERMS.md)
