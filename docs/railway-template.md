# Railway Template: Frontman

Use this content when publishing the Frontman Railway template.

## Template Metadata

**Name:** Frontman

**Subtitle:** Self-host the browser-native AI frontend agent.

**Category:** Developer Tools

**Description:** Self-host Frontman, the browser-native AI frontend agent. Includes the Phoenix orchestration server, PostgreSQL, automatic migrations, OAuth via WorkOS, and optional Resend/Discord integrations.

**Repository:** `https://github.com/frontman-ai/frontman`

**Website:** https://frontman.sh

**Dockerfile path:** `apps/frontman_server/Dockerfile`

**Pre-deploy command:**
```bash
/app/bin/frontman_server eval "FrontmanServer.Release.migrate()"
```

**Healthcheck path:** `/health`

## Services

### Frontman

Phoenix orchestration server that handles user accounts, task history, AI agent execution, browser MCP tool calls, and WebSocket connections from the Frontman client libraries.

### Postgres

Persistent storage for user accounts, task history, OAuth tokens, encrypted API keys, and Oban background jobs.

## Required Variables

```dotenv
PHX_SERVER=true
PHX_HOST=${{Frontman.RAILWAY_PUBLIC_DOMAIN}}
DATABASE_URL=${{Postgres.DATABASE_URL}}
DATABASE_SSL=true
SECRET_KEY_BASE=<generated secret, 64+ chars>
CLOAK_KEY=<generated secret, 32-byte base64>
WORKOS_API_KEY=<user-provided WorkOS API key>
WORKOS_CLIENT_ID=<user-provided WorkOS client ID>
```

## Optional Variables

```dotenv
RESEND_API_KEY=<enables welcome emails and contact sync>
DISCORD_NEW_USERS_WEBHOOK_URL=<enables new-user signup notifications>
POOL_SIZE=10
```

## Landing Page Content

# Deploy and Host Frontman with one click on Railway

Frontman is an open-source AI coding agent that lives in your browser. Click any element in your running app, describe the change in plain English, and Frontman edits the actual source files with instant hot reload.

Learn more at https://frontman.sh or view the source at https://github.com/frontman-ai/frontman.

Self-hosting Frontman on Railway gives your team its own orchestration server with managed PostgreSQL, automatic HTTPS, release health checks, and database migrations before each deploy.

## About Hosting Frontman on Railway

Frontman uses a split architecture. Your application installs a framework integration for Next.js, Astro, or Vite. That integration exposes live browser and server context through MCP tools. The Frontman server coordinates the AI agent, user accounts, task history, WebSocket sessions, OAuth, and encrypted API keys.

Railway is a good fit for teams that want self-hosted Frontman without maintaining a VM, Caddy, systemd units, PostgreSQL backups, or manual release scripts.

## Why Deploy Frontman on Railway

Deploying Frontman on Railway removes most operational work from self-hosting:

- Automatic HTTPS for the Frontman server
- Managed PostgreSQL for users, tasks, and Oban jobs
- Docker-based builds from the open-source repository
- Database migrations before each deploy
- Health checks against `/health`
- Optional Resend and Discord integrations

## Common Use Cases for Frontman

1. **Design QA fixes:** Click a broken UI element and ask Frontman to fix spacing, colors, copy, or responsive behavior.
2. **Product-led frontend edits:** Let product managers propose small UI changes without opening an IDE.
3. **Internal tool polish:** Fix admin panels, dashboards, and internal workflows where handoff cost exceeds code cost.
4. **Rendered-page debugging:** Use live DOM, computed CSS, source maps, routes, and server logs instead of guessing from static files.
5. **Team-controlled self-hosting:** Keep the orchestration server, accounts, and task history in your own Railway project.

## Dependencies for Frontman Hosted on Railway

Frontman requires the Phoenix server and PostgreSQL. Railway provisions PostgreSQL and injects `DATABASE_URL` into the Frontman service through a reference variable.

Required external setup:

- WorkOS application for OAuth login
- GitHub or Google OAuth provider configured in WorkOS
- Optional Resend API key for email delivery
- Optional Discord webhook for signup notifications

### Deployment Dependencies

- Railway PostgreSQL service for persistent application data
- Railway public networking for HTTPS and WebSocket traffic
- WorkOS application credentials for OAuth login
- Optional Resend API key for transactional email
- Optional Discord webhook for signup notifications

## Implementation Details

The Frontman Docker image builds from `apps/frontman_server/Dockerfile` using the repository root as build context. The root context is required because the Phoenix server depends on monorepo packages in `libs/`.

Before each deployment becomes active, Railway runs:

```bash
/app/bin/frontman_server eval "FrontmanServer.Release.migrate()"
```

The server exposes `/health` for deployment health checks and listens on Railway's `PORT` environment variable.

## How to Use Frontman After Deploy

1. Deploy this template on Railway.
2. Configure `WORKOS_API_KEY` and `WORKOS_CLIENT_ID`.
3. Configure your WorkOS redirect URL for the Railway public domain.
4. Install a Frontman integration in your app:
   - `npx @frontman-ai/nextjs install`
   - `astro add @frontman-ai/astro`
   - `npx @frontman-ai/vite install`
5. Point the integration at your self-hosted Frontman server if required by your environment.
6. Open `/frontman` in your running app, sign in, select an element, and request a frontend change.

## System Requirements

- PostgreSQL 17+
- 1 GB RAM minimum for small teams
- 1 vCPU minimum for light usage
- Outbound HTTPS access to LLM providers and OAuth providers
- WebSocket support for live browser sessions

## FAQs

### What is Frontman?

Frontman is an open-source AI frontend agent that starts from the rendered browser page, maps selected elements back to source code, and edits your app with hot reload feedback.

### Does Frontman replace Cursor or Copilot?

No. Cursor and Copilot work primarily from source files inside an IDE. Frontman works from the browser and is strongest for visual frontend edits where rendered DOM, computed CSS, and component ownership matter.

### What data is stored in Postgres?

Frontman stores user accounts, task history, OAuth tokens, encrypted API keys, and background job state.

### Is WorkOS required?

Yes for production login. Frontman uses WorkOS for OAuth with providers like GitHub and Google.

### Are Resend and Discord required?

No. Frontman disables welcome-email, contact-sync, and signup-notification workers unless `RESEND_API_KEY` or `DISCORD_NEW_USERS_WEBHOOK_URL` are present.

### Does the Railway-hosted server edit my Railway project?

No. Frontman edits the app where the Frontman framework integration is installed and running. The Railway deployment hosts the orchestration server.

### Can I still self-host with Docker instead of Railway?

Yes. Railway uses the same Dockerfile-backed server deployment. Use Railway for managed hosting, or run the Docker image directly on your own infrastructure.

### Which frameworks does Frontman support?

Frontman supports Next.js, Astro, and Vite apps, including React, Vue, Svelte, and SvelteKit projects through the Vite integration.
