---
title: Self-Hosting
description: Run the Frontman server yourself — architecture, requirements, deployment options, and commercial considerations.
---

## Overview

Frontman uses a split architecture:

- **Client libraries** (browser-side MCP servers) — bundled into your app via npm packages (`@frontman-ai/nextjs`, `@frontman-ai/astro`, `@frontman-ai/vite`)
- **Server** (AI agent orchestration) — Elixir/Phoenix application that queries MCP tools, generates edits, and writes source files

For local development, the server runs at `api.frontman.sh` (our hosted instance). **Self-hosting is only needed if you want to run your own instance of the orchestration server** — for data sovereignty, air-gapped environments, or custom modifications.

:::note[When to self-host]
**Most users don't need to self-host.** The client libraries are open source (Apache 2.0) and run entirely in your browser. Your source code never leaves your machine. The hosted server at `api.frontman.sh` only receives MCP tool calls (DOM queries, file reads/writes) and returns edits.

Consider self-hosting if you:
- Work in an air-gapped environment (no internet access)
- Have strict data residency requirements
- Want to fork and modify the server codebase
- Need guaranteed uptime SLAs not covered by the hosted service
:::

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│ Your Machine                                    │
│ ┌─────────────────┐  ┌────────────────────────┐ │
│ │ Dev Server      │  │ Browser                 │ │
│ │ (Next/Astro/    │  │ (Frontman overlay)      │ │
│ │  Vite)          │  │                         │ │
│ │                 │  │ Browser-side MCP Server │ │
│ │ Server-side     │  │ (DOM, CSS, screenshots) │ │
│ │ MCP tools       │  └───────────┬─────────────┘ │
│ │ (routes, logs,  │              │               │
│ │  build errors)  │              │               │
│ └────────┬────────┘              │               │
└──────────┼───────────────────────┼───────────────┘
           │                       │
           │    WebSocket/HTTPS    │
           └───────────┬───────────┘
                       │
┌──────────────────────┼───────────────────────────┐
│ Frontman Server      │  (Elixir/Phoenix)         │
│  ┌───────────────────▼──────────────────────┐    │
│  │ AI Agent Orchestrator                    │    │
│  │ - Queries MCP tools (browser + server)   │    │
│  │ - Calls LLM (Claude/GPT/OpenRouter)      │    │
│  │ - Generates code edits                   │    │
│  │ - Writes to source files via MCP         │    │
│  │ - Triggers hot reload                    │    │
│  └──────────────────────────────────────────┘    │
│                                                   │
│  PostgreSQL (user accounts, task history)        │
│  Oban (background jobs: email, webhooks)         │
│  OpenTelemetry (optional observability)          │
└───────────────────────────────────────────────────┘
```

The server is stateless except for PostgreSQL. Horizontal scaling is supported via Elixir's distributed runtime (RELEASE_DISTRIBUTION=name).

---

## Requirements

### Runtime
- **Elixir** 1.19+ and **Erlang/OTP** 28+ (BEAM VM)
- **PostgreSQL** 17+ (for user accounts and task history)
- **Node.js** 24+ (for building assets — not needed in production)
- **Linux** x86_64 or ARM64 (Ubuntu 24.04 LTS recommended)

### Build-time (optional, for Docker or releases)
- **Yarn** 4+ (monorepo dependency management)
- **ReScript** 12+ (client library compilation)

### Resources (production)
- **Minimum:** 1 vCPU, 2GB RAM, 20GB disk
- **Recommended:** 2 vCPU, 4GB RAM, 50GB disk (allows PostgreSQL tuning and room for logs)
- **Storage:** Database grows with task history. Plan ~1GB/month for 100 active users. Backups require 2x database size.

### Network
- Outbound HTTPS to LLM APIs (Anthropic, OpenAI, OpenRouter)
- Inbound HTTPS (443) for client connections
- WebSocket support required (Phoenix Channels)

---

## Deployment Options

### Option 1: Bare Metal / VM (Recommended for Production)

This is how we run `api.frontman.sh` — a single Hetzner server with blue/green deploys.

**Prerequisites:**
- Ubuntu 24.04 LTS server
- DNS A record pointing to server IP (we use Cloudflare DNS-only mode)
- SSH access as root

**Setup:**
```bash
# 1. Run server setup script (installs PostgreSQL, Caddy, systemd services)
ssh root@<server-ip> 'bash -s' < infra/production/server-setup.sh

# 2. Fill in environment secrets
ssh deploy@<server-ip>
nano /opt/frontman/blue/env
# Set CLOAK_KEY, WORKOS_API_KEY, WORKOS_CLIENT_ID, etc.

# 3. Deploy first release (GitHub Actions workflow builds and deploys on push to main)
# Or manually:
git clone https://github.com/frontman-ai/frontman.git
cd frontman
make -C apps/frontman_server release
scp apps/frontman_server/_build/prod/frontman_server-*.tar.gz deploy@<server>:/tmp/
ssh deploy@<server> '/opt/frontman/deploy.sh /tmp/frontman_server-*.tar.gz'
```

**What the setup script does:**
- Installs PostgreSQL 17 with production tuning (auto-detects RAM)
- Creates `frontman` database user and `frontman_server_prod` database
- Installs Caddy reverse proxy (auto TLS via Let's Encrypt)
- Creates `/opt/frontman/{blue,green}` directories for blue/green deploys
- Installs systemd services (`frontman-blue.service`, `frontman-green.service`)
- Sets up nightly PostgreSQL backups (cron at 3:00 AM)
- Configures UFW firewall (22, 80, 443) and fail2ban

**Blue/Green Deployment:**
The deploy script (`/opt/frontman/deploy.sh`) extracts the release to the inactive slot, runs migrations, smoke tests the new version, then swaps Caddy's upstream. Zero-downtime deploys. Rollback via `/opt/frontman/rollback.sh`.

**Monitoring (optional):**
```bash
# Install Prometheus, Alertmanager, Blackbox Exporter
ssh root@<server> 'bash -s' < infra/production/monitoring/setup-monitoring.sh
```
Exports to Arize via OpenTelemetry if `ARIZE_API_KEY` and `ARIZE_SPACE_ID` are set in env.

---

### Option 2: Docker

**Build the image:**
```bash
cd apps/frontman_server
docker build -t frontman-server .
```

**Run (single instance):**
```bash
docker run -d \
  --name frontman-server \
  -p 4000:4000 \
  -e DATABASE_URL='ecto://user:pass@postgres-host/frontman_server_prod' \
  -e SECRET_KEY_BASE='<generate via: mix phx.gen.secret>' \
  -e CLOAK_KEY='<generate via: openssl rand -base64 32>' \
  -e WORKOS_API_KEY='<your-workos-api-key>' \
  -e WORKOS_CLIENT_ID='<your-workos-client-id>' \
  frontman-server
```

**Environment variables:** See `infra/production/env.template` for full list. Required:
- `DATABASE_URL` — PostgreSQL connection string
- `SECRET_KEY_BASE` — Session encryption (generate: `mix phx.gen.secret`)
- `CLOAK_KEY` — API key encryption at rest (generate: `openssl rand -base64 32`)
- `WORKOS_API_KEY`, `WORKOS_CLIENT_ID` — OAuth (GitHub, Google login)

Optional:
- `ARIZE_API_KEY`, `ARIZE_SPACE_ID` — OpenTelemetry export
- `DISCORD_NEW_USERS_WEBHOOK_URL` — New user signup notifications
- `RESEND_API_KEY` — Email delivery (welcome emails, password resets)

**PostgreSQL setup:**
```bash
# Run postgres container
docker run -d \
  --name frontman-postgres \
  -e POSTGRES_DB=frontman_server_prod \
  -e POSTGRES_USER=frontman \
  -e POSTGRES_PASSWORD='<random-password>' \
  -v frontman-pg-data:/var/lib/postgresql/data \
  postgres:17-alpine

# Run migrations (first time only)
docker exec frontman-server /app/bin/frontman_server eval "FrontmanServer.Release.migrate()"
```

---

### Option 3: From Source (Development)

**Prerequisites:**
- Elixir 1.19+, Erlang 28+, Node.js 24+, PostgreSQL 17+
- Yarn 4+ (enable via `corepack enable`)

**Setup:**
```bash
git clone https://github.com/frontman-ai/frontman.git
cd frontman

# 1. Install dependencies
yarn install
cd apps/frontman_server
mix deps.get

# 2. Create database
mix ecto.create
mix ecto.migrate

# 3. Install assets (esbuild, tailwind)
mix setup

# 4. Configure environment
cp envs/.dev.env envs/.dev.local.env
# Edit .dev.local.env with your API keys

# 5. Start server
mix phx.server
# Visit http://localhost:4000
```

**Configuration:** Uses Dotenvy to load env files in this order:
1. `envs/.env` (base config, checked into git)
2. `envs/.dev.env` (dev defaults)
3. `envs/.dev.overrides.env` (local overrides, gitignored)
4. System environment variables (highest precedence)

Secrets (WorkOS keys, LLM API keys) are stored in `envs/.dev.secrets.env` as `op://` references (1Password CLI). The Makefile wraps `mix phx.server` with `op run --env-file=envs/.dev.secrets.env` to inject them at runtime. If you don't use 1Password, set them directly in `.dev.overrides.env`.

---

## Configuration

### Required Environment Variables

#### Application
- `PHX_HOST` — Public hostname (e.g., `api.frontman.sh`)
- `PHX_SERVER=true` — Start Phoenix HTTP endpoint
- `PORT` — HTTP port (default: 4000)

#### Database
- `DATABASE_URL` — PostgreSQL connection string
  - Format: `ecto://user:pass@host/database`
  - Example: `ecto://frontman:secretpass@localhost/frontman_server_prod`
- `DATABASE_SSL` — Enable SSL (default: true in prod)
  - Set to `false` for local PostgreSQL without SSL

#### Security
- `SECRET_KEY_BASE` — Phoenix session encryption
  - Generate: `mix phx.gen.secret`
  - Must be 64+ characters
- `CLOAK_KEY` — API key encryption at rest (Cloak Ecto)
  - Generate: `openssl rand -base64 32`

#### Authentication (WorkOS)
Frontman uses WorkOS for OAuth (GitHub, Google login). Required for production:
- `WORKOS_API_KEY` — WorkOS API secret
- `WORKOS_CLIENT_ID` — WorkOS OAuth client ID

Get these from [WorkOS Dashboard](https://dashboard.workos.com/).

### Optional Environment Variables

#### Observability (OpenTelemetry → Arize)
- `ARIZE_API_KEY` — Arize Phoenix API key
- `ARIZE_SPACE_ID` — Arize space ID
- `ARIZE_COLLECTOR_ENDPOINT` — Default: `https://otlp.eu-west-1a.arize.com`
- `ARIZE_PROJECT_NAME` — Default: `frontman`

If both API key and space ID are set, spans are exported to Arize. Otherwise, telemetry collection is disabled.

#### Notifications
- `DISCORD_NEW_USERS_WEBHOOK_URL` — Discord webhook for new user signups (omit to disable)

#### Email (Resend)
- `RESEND_API_KEY` — Required for welcome emails and password resets in production

#### Database Tuning
- `POOL_SIZE` — Ecto connection pool size (default: 10)
- `ECTO_IPV6` — Set to `true` or `1` to use IPv6

#### Clustering (Distributed Elixir)
- `RELEASE_NODE` — Node name (e.g., `frontman@127.0.0.1`)
- `RELEASE_COOKIE` — Erlang distribution cookie (shared secret for clustering)
- `RELEASE_DISTRIBUTION=name` — Enable distributed mode
- `DNS_CLUSTER_QUERY` — DNS SRV query for node discovery (e.g., `_frontman._tcp.internal.local`)

---

## Database Management

### Migrations
```bash
# Production (inside release)
/app/bin/frontman_server eval "FrontmanServer.Release.migrate()"

# Development
mix ecto.migrate
```

### Backups
The setup script installs a daily backup cron (3:00 AM) that dumps PostgreSQL to `/opt/frontman/backups/daily/`. Retention: 7 days. Adjust in `/opt/frontman/backup-pg.sh`.

**Manual backup:**
```bash
pg_dump -U frontman frontman_server_prod | gzip > backup-$(date +%Y%m%d).sql.gz
```

**Restore:**
```bash
gunzip < backup-YYYYMMDD.sql.gz | psql -U frontman frontman_server_prod
```

### Rollback
```bash
# Via deploy script (rolls back to previous release)
ssh deploy@<server> '/opt/frontman/rollback.sh'

# Manual Ecto rollback (dev)
mix ecto.rollback --step 1
```

---

## Security Considerations

### Data Flow
- **Source code:** Never uploaded to the server. The browser-side MCP server reads files locally and sends diffs to the server. The server writes patches back via MCP file write tools.
- **Secrets:** LLM API keys are encrypted at rest in PostgreSQL using Cloak Ecto (AES-256-GCM). The `CLOAK_KEY` env var decrypts them.
- **OAuth tokens:** WorkOS handles GitHub/Google OAuth. Frontman receives an auth code, exchanges it for user info, and stores a session cookie (Phoenix signed sessions).

### Transport Security
- **HTTPS required in production.** Caddy auto-provisions Let's Encrypt TLS certificates.
- **WebSocket encryption:** Phoenix Channels run over WSS (WebSocket Secure) in production.

### Authentication
- **OAuth via WorkOS** — GitHub and Google SSO
- **Session-based** — Phoenix signed cookies (`SECRET_KEY_BASE`)
- **No password storage** — OAuth-only (no email/password login)

### Firewall
The setup script configures UFW to allow only SSH (22), HTTP (80), HTTPS (443). PostgreSQL (5432) is bound to localhost only.

### Secrets Management
**Never commit secrets to git.** Use:
- Environment files (`.env`) for non-sensitive config (gitignored)
- Secret managers (1Password CLI, AWS Secrets Manager, HashiCorp Vault) for production

Example with 1Password CLI (used in our dev workflow):
```bash
# .dev.secrets.env
WORKOS_API_KEY=op://vault/WorkOS/API_Key

# Run server with secrets injected
op run --env-file=envs/.dev.secrets.env mix phx.server
```

---

## Monitoring & Observability

### Health Checks
- **HTTP:** `GET /api/health` → `{"status": "ok"}`
- **Database:** Phoenix Dashboard at `/dashboard` (dev only)

### Logs
- **Development:** Console output (colorized via Phoenix Logger)
- **Production:** Systemd journal (`journalctl -u frontman-blue -f`)
- **Structured logging:** JSON format via Logger (configurable in `config/prod.exs`)

### Metrics (Prometheus)
Optional setup script installs Prometheus + Alertmanager + Blackbox Exporter. Scrapes:
- BEAM VM metrics (via `TelemetryMetrics`)
- HTTP request rates, latencies (Phoenix instrumentation)
- Database query timing (Ecto telemetry)
- Health endpoint uptime (Blackbox Exporter)

Alerts fire to Alertmanager → Discord webhook on:
- Instance down (health check fails for 1 minute)
- High error rate (>5% 5xx responses over 5 minutes)
- Database connection pool exhausted

### Distributed Tracing
If `ARIZE_API_KEY` and `ARIZE_SPACE_ID` are set, OpenTelemetry spans are exported to Arize Phoenix for LLM observability (prompt tracing, token usage, latency).

---

## Scaling & High Availability

### Horizontal Scaling
Frontman is stateless except for PostgreSQL. To scale horizontally:

1. **Run multiple instances** behind a load balancer (e.g., Caddy with `lb_policy round_robin`)
2. **Shared PostgreSQL** — all instances connect to the same database
3. **Distributed Elixir** — set `RELEASE_NODE`, `RELEASE_COOKIE`, `RELEASE_DISTRIBUTION=name`, and `DNS_CLUSTER_QUERY` for node discovery

Example (3 nodes):
```bash
# Node 1
RELEASE_NODE=frontman1@10.0.1.10 RELEASE_COOKIE=secret /app/bin/server

# Node 2
RELEASE_NODE=frontman2@10.0.1.11 RELEASE_COOKIE=secret /app/bin/server

# Node 3
RELEASE_NODE=frontman3@10.0.1.12 RELEASE_COOKIE=secret /app/bin/server
```

Nodes will form a cluster. Phoenix PubSub messages (task updates, hot reload triggers) are distributed across all nodes.

### Database HA
For production, use:
- **PostgreSQL replication** (streaming replication + failover via Patroni or Stolon)
- **Managed databases** (AWS RDS, GCP Cloud SQL, Azure PostgreSQL)

### Backup Strategy
- **Automated daily backups** (setup script installs cron)
- **Offsite storage** (rsync to S3, GCS, or Backblaze B2)
- **Test restores regularly** (quarterly is recommended)

---

## Commercial Considerations

### Licensing
- **Client libraries** (`libs/`) — Apache 2.0 (permissive, commercial use allowed)
- **Server** (`apps/frontman_server/`) — AGPL-3.0 (copyleft, requires source disclosure if distributed)

If you self-host, you must:
- Provide source code to users who interact with your modified server (AGPL network clause)
- Disclose modifications if you distribute the server

**Commercial licenses available** — contact us if AGPL doesn't fit your use case (e.g., SaaS white-label, proprietary forks). See [AI-SUPPLEMENTARY-TERMS.md](https://github.com/frontman-ai/frontman/blob/main/AI-SUPPLEMENTARY-TERMS.md) for AI training restrictions.

### Support
Self-hosted deployments are community-supported via:
- [GitHub Issues](https://github.com/frontman-ai/frontman/issues) (bug reports, feature requests)
- [Discord](https://discord.gg/xk8uXJSvhC) (community help)

**Enterprise support** available (SLA-backed, private Slack channel, dedicated engineer). Includes:
- Custom deployment consulting
- Priority bug fixes and backports
- Security patches with 24-hour SLA
- Performance tuning and database optimization

Contact [enterprise@frontman.sh](mailto:enterprise@frontman.sh) for pricing.

### Cloud Marketplaces
Not currently available on AWS/GCP/Azure marketplaces. Roadmap item for 2025. Track progress in [issue #123](https://github.com/frontman-ai/frontman/issues/123).

### Multi-Tenancy
The hosted `api.frontman.sh` runs a single instance serving all users. Self-hosted deployments can run:
- **Single-tenant** (one org, one database)
- **Multi-tenant** (multiple orgs, shared database with row-level security)

Multi-tenancy is implemented via `organization_id` foreign keys + Ecto query scoping. See `apps/frontman_server/lib/frontman_server/organizations.ex` for details.

### Cost Estimates

#### Hosted (api.frontman.sh)
- **Free** — no subscription fees, no usage limits
- **BYOK** — you pay your LLM provider directly (Anthropic, OpenAI, OpenRouter) at standard API rates

#### Self-Hosted (estimated monthly costs)
- **Hetzner CCX13** (2 vCPU, 8GB RAM, 80GB NVMe) — €15/month (~$16 USD)
- **PostgreSQL** (included on VM)
- **Backups** (Hetzner Backup +20%) — €3/month (~$3 USD)
- **Total:** ~€18/month (~$19 USD)

Compare to:
- **Cursor Pro** — $20/month/user
- **GitHub Copilot Pro** — $10/month/user
- **v0 Premium** — $20/month/user

Self-hosting is cost-effective for teams of 2+ users.

---

## Troubleshooting

### Server won't start
```bash
# Check systemd logs
journalctl -u frontman-blue -f

# Common issues:
# 1. DATABASE_URL incorrect → check /opt/frontman/blue/env
# 2. SECRET_KEY_BASE missing → generate: mix phx.gen.secret
# 3. Port already in use → check: sudo lsof -i :4000
```

### Database connection errors
```bash
# Test PostgreSQL connection
psql -U frontman -h localhost frontman_server_prod

# Check PostgreSQL status
systemctl status postgresql

# Check pg_hba.conf auth
sudo cat /etc/postgresql/17/main/pg_hba.conf | grep frontman
```

### Migrations fail
```bash
# Run manually with debug output
/app/bin/frontman_server eval "FrontmanServer.Release.migrate()" --verbose

# Rollback and retry
mix ecto.rollback --step 1
mix ecto.migrate
```

### WebSocket connections drop
- **Caddy timeout:** Increase `timeout` in Caddyfile (default: 5 minutes)
- **Firewall:** Ensure TCP 443 allows long-lived connections (disable stateful inspection if needed)

### Out of memory (OOM)
```bash
# Check BEAM memory usage
/app/bin/frontman_server remote

# In IEx console:
:erlang.memory()
# Look for 'total' — should be < 80% of available RAM

# Tune VM (add to env):
ERL_AFLAGS="+MBas aoffcbf +MBac false +MBlmbcs 512"
```

### High database load
```bash
# Check slow queries (inside psql):
SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;

# Add indexes (migrations in apps/frontman_server/priv/repo/migrations/)
# Run: mix ecto.gen.migration add_index_to_tasks
```

---

## Upgrade Guide

### Minor Versions (0.x.y → 0.x.z)
Safe to deploy without downtime (backward-compatible migrations):
```bash
# Deploy via GitHub Actions (push to main)
git push origin main

# Or manually:
ssh deploy@<server> '/opt/frontman/deploy.sh /tmp/new-release.tar.gz'
```

### Major Versions (0.x → 1.0)
May require manual migration steps:
1. **Read CHANGELOG.md** for breaking changes
2. **Backup database** (`/opt/frontman/backup-pg.sh`)
3. **Deploy to green slot** (test before swapping)
4. **Run migrations** (deploy script does this automatically)
5. **Smoke test** (deploy script checks health endpoint)
6. **Swap Caddy upstream** (deploy script updates Caddyfile)

Rollback if needed: `/opt/frontman/rollback.sh`

---

## FAQ

### Do I need to self-host?
**No** — most users should use `api.frontman.sh` (our hosted instance). Self-host only if you need data sovereignty, air-gapped environments, or custom server modifications.

### Can I run Frontman without a server?
**No** — the server orchestrates AI agent execution. The client libraries (Next.js/Astro/Vite plugins) are just MCP servers that expose dev server context to the agent.

### Is the database required?
**Yes** — stores user accounts, OAuth tokens, task history, and encrypted API keys.

### Can I use MySQL instead of PostgreSQL?
**No** — Ecto migrations use PostgreSQL-specific features (JSONB, UUID extensions). MySQL support is not planned.

### How do I change the domain?
1. Update `PHX_HOST` in `/opt/frontman/blue/env` and `/opt/frontman/green/env`
2. Update Caddy config: `/etc/caddy/Caddyfile`
3. Reload Caddy: `sudo systemctl reload caddy`
4. Update DNS A record to point to your server

### Can I disable OAuth and use email/password?
**Not currently supported.** OAuth via WorkOS is the only auth method. Email/password login is a roadmap item for 2025 (track in [issue #456](https://github.com/frontman-ai/frontman/issues/456)).

### How do I add a new LLM provider?
See the [Models & Providers](/docs/reference/models/) reference for currently supported providers. To add a new provider in a self-hosted fork:
1. Add provider config to `apps/frontman_server/config/config.exs`
2. Implement API adapter in `apps/frontman_server/lib/frontman_server/providers/`
3. Add OAuth flow if needed (WorkOS or custom)

---

## Resources

- [GitHub Repository](https://github.com/frontman-ai/frontman)
- [Production Deployment Scripts](https://github.com/frontman-ai/frontman/tree/main/infra/production)
- [Dockerfile](https://github.com/frontman-ai/frontman/blob/main/apps/frontman_server/Dockerfile)
- [Environment Template](https://github.com/frontman-ai/frontman/blob/main/infra/production/env.template)
- [Discord Community](https://discord.gg/xk8uXJSvhC)

For enterprise support or commercial licensing questions, contact [enterprise@frontman.sh](mailto:enterprise@frontman.sh).
