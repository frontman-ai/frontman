# Remote Development with DevPod

This guide explains how to use DevPod to run Frontman development environments on a remote Hetzner server.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Hetzner Cloud Server (see root .env → DEVPOD_SERVER)                    │
│  CX33: 8 vCPU, 8GB RAM, 80GB NVMe + 4GB swap                            │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Caddy Reverse Proxy (ports 80/443)                             │    │
│  │  Routes: {hash}.{service}.frontman.local → container            │    │
│  └──────────────────────────────┬──────────────────────────────────┘    │
│                                 │                                       │
│  ┌──────────────────────────────┼──────────────────────────────────┐    │
│  │ Docker                       │                                  │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │    │
│  │  │ wt-ea0c     │  │ wt-b09b     │  │ wt-xxxx     │  ...         │    │
│  │  │ (issue-164) │  │ (issue-189) │  │ (feature-X) │              │    │
│  │  │ :4000 :5173 │  │ :4000 :5173 │  │ :4000 :5173 │              │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│  PostgreSQL 16 (shared across workspaces)                               │
└─────────────────────────────────────────────────────────────────────────┘
          ↑
          │ DNS via dnsmasq (*.{service}.frontman.local → DEVPOD_SERVER)
          │ Direct HTTPS (port 443)
          ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  Your Local Machine                                                     │
│  - dnsmasq: *.api.frontman.local → DEVPOD_SERVER (one-time setup)       │
│  - Browser: https://ea0c.nextjs.frontman.local/frontman                │
│  - All services accessible via subdomains, any new hash works instantly │
└─────────────────────────────────────────────────────────────────────────┘
```

## URL Scheme

Each worktree gets a unique 4-character hash ID based on its name. URLs follow this format for WorkOS OAuth compatibility:

```
https://{hash}.{service}.frontman.local
```

| Worktree | Hash | Next.js URL | Vite URL | Phoenix URL |
|----------|------|-------------|----------|-------------|
| issue-164 | ea0c | https://ea0c.nextjs.frontman.local | https://ea0c.vite.frontman.local | https://ea0c.api.frontman.local |
| issue-189 | b09b | https://b09b.nextjs.frontman.local | https://b09b.vite.frontman.local | https://b09b.api.frontman.local |

Services per worktree:
- `{hash}.nextjs.frontman.local` - Next.js dev server (port 3000) - access at `/frontman`
- `{hash}.vite.frontman.local` - Vite client dev server (port 5173)
- `{hash}.api.frontman.local` - Phoenix server (port 4000)
- `{hash}.storybook.frontman.local` - Storybook (port 6006)

**Important:** The URL format `{hash}.{service}.frontman.local` is required for WorkOS OAuth redirects to work correctly. WorkOS needs consistent redirect URIs, and this subdomain pattern allows multiple development environments while maintaining OAuth compatibility.

## Server IP

The Hetzner server IP is stored in 1Password and referenced via the root `.env` file:

```bash
# .env (gitignored)
DEVPOD_SERVER=op://frontman/DEVPOD_SERVER
```

To resolve the actual IP, run:
```bash
op read "op://frontman/DEVPOD_SERVER"
```

All references to `DEVPOD_SERVER` in this document should be replaced with the resolved IP.

## Prerequisites

- SSH key configured (already done if you can `ssh root@DEVPOD_SERVER`)
- DevPod CLI installed locally
- mkcert installed locally (`brew install mkcert`)
- dnsmasq installed and configured (see [DNS Setup](#2-dns-setup-with-dnsmasq) below)

## Quick Start

```bash
# 1. Set up dnsmasq (one-time, see DNS Setup section below)

# 2. Get URLs for your worktree
make wt-urls BRANCH=issue-164
```

## Setup

### 1. Install DevPod

```bash
# macOS
brew install devpod

# Linux
curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64"
chmod +x devpod
sudo mv devpod /usr/local/bin/

# Verify installation
devpod version
```

### 2. DNS Setup with dnsmasq

Instead of manually adding `/etc/hosts` entries for each worktree, we use dnsmasq for wildcard DNS resolution. This is a **one-time setup** — any new worktree hash will resolve automatically.

dnsmasq resolves `*.{service}.frontman.local` directly to the Hetzner server IP, so requests go straight to Caddy on the server (no SSH tunnel needed).

#### Install dnsmasq

```bash
brew install dnsmasq
```

#### Configure dnsmasq

Create the config file at `/opt/homebrew/etc/dnsmasq.d/frontman.conf`:

```bash
cat > /opt/homebrew/etc/dnsmasq.d/frontman.conf << 'EOF'
# Frontman DevPod remote development
# Resolves service subdomains to the Hetzner DevPod server
# This enables URLs like:
#   - ea0c.api.frontman.local -> DEVPOD_SERVER
#   - ea0c.nextjs.frontman.local -> DEVPOD_SERVER
#   - ea0c.vite.frontman.local -> DEVPOD_SERVER
#   - ea0c.storybook.frontman.local -> DEVPOD_SERVER

# All *.api.frontman.local
address=/api.frontman.local/DEVPOD_SERVER

# All *.nextjs.frontman.local
address=/nextjs.frontman.local/DEVPOD_SERVER

# All *.vite.frontman.local
address=/vite.frontman.local/DEVPOD_SERVER

# All *.storybook.frontman.local
address=/storybook.frontman.local/DEVPOD_SERVER
EOF
```

#### Create macOS resolver files

macOS uses `/etc/resolver/` to delegate DNS queries for specific domains to custom nameservers. Create one file per service domain:

```bash
sudo mkdir -p /etc/resolver

for service in api nextjs vite storybook; do
  echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/${service}.frontman.local > /dev/null
done
```

#### Start dnsmasq

```bash
sudo brew services start dnsmasq
```

#### Verify it works

```bash
# Should resolve to DEVPOD_SERVER
dig +short test.api.frontman.local @127.0.0.1
dig +short abcd.nextjs.frontman.local @127.0.0.1

# Verify macOS resolver picks it up (may take a few seconds)
dscacheutil -q host -a name test.api.frontman.local
```

### 3. Add Hetzner Server as SSH Provider

```bash
# Add the SSH provider with our Hetzner server
devpod provider add ssh --option HOST=root@DEVPOD_SERVER
```

### 4. Create Your First Workspace

```bash
# Create a workspace from the main branch
devpod up github.com/frontman-ai/frontman --id main --source git:https://github.com/frontman-ai/frontman

# Or from a feature branch
devpod up github.com/frontman-ai/frontman --id my-feature --source git:https://github.com/frontman-ai/frontman@my-feature
```

This will:
1. Clone the repo on the remote server
2. Build the devcontainer image
3. Install all runtimes (Node.js, Elixir, etc.) via mise
4. Run `make install` to get dependencies

> **Note:** This only sets up the container. Dev servers (Phoenix, Vite, Next.js) are **not** started automatically — you must start them after connecting (see [Inside the Workspace](#inside-the-workspace)).

### 5. Connect Your IDE

```bash
# Open in VS Code
devpod up main --ide vscode

# Or use SSH directly
devpod ssh main
```

## Daily Workflow

### Starting Work

```bash
# List available workspaces
devpod list

# Start/connect to a workspace
devpod up my-feature --ide vscode
```

### Inside the Workspace

Once connected, you can run the standard dev commands:

```bash
# Terminal 1: ReScript compiler
make dev

# Terminal 2: Vite client dev server (port 5173)
make dev-client

# Terminal 3: Elixir Phoenix server (port 4000)
make dev-server

# Terminal 4: Next.js test site (port 3000)
make dev-nextjs
```

### Accessing Services via Browser

With dnsmasq configured, services are accessible directly. Get your worktree URLs:

```bash
make wt-urls BRANCH=your-branch
```

Then open in your browser:

- `https://xxxx.nextjs.frontman.local/frontman` - Next.js (Frontman UI)
- `https://xxxx.vite.frontman.local` - Vite client
- `https://xxxx.api.frontman.local` - Phoenix server
- `https://xxxx.storybook.frontman.local` - Storybook

The services are routed through Caddy reverse proxy on the server, which handles SSL termination.

> **Important:** `devpod up` only creates the container — it does **not** do the following, which must be done manually:
>
> 1. **Register with Caddy** — No `.caddy` config is created, so URLs return `HTTP 200, 0 bytes`
> 2. **Generate SSL certs** — Phoenix needs `.certs/frontman.local-key.pem` to start
> 3. **Copy secrets** — WorkOS keys and API keys aren't in the container
> 4. **Fix DB_HOST** — `host.docker.internal` may not resolve; use the Docker gateway IP (`172.17.0.1`)
> 5. **Build workspace packages** — `@frontman-ai/nextjs` needs to be built before Next.js works
> 6. **Start dev servers** — No processes are launched in the container
>
> #### Post-creation checklist
>
> ```bash
> # 1. Get your worktree hash
> make wt-urls BRANCH=your-branch
> # Note the 4-char hash (e.g. 3ce7)
>
> # 2. Register with Caddy (from your local machine)
> # Get the container name:
> ssh root@DEVPOD_SERVER 'docker ps --format "{{.Names}} {{.Status}}"'
> # Get container IP:
> ssh root@DEVPOD_SERVER 'docker inspect CONTAINER_NAME --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'
> # Create /etc/caddy/worktrees/{hash}.caddy (copy an existing file and replace hash + IP)
> # Then: ssh root@DEVPOD_SERVER 'systemctl reload caddy'
>
> # 3. Copy secrets to the container (from your local machine)
> # This copies WorkOS keys, API keys, etc. from your local .dev.overrides.env
> grep -E "^(WORKOS_|BRAINTRUST_|OPENAI_|OPEN_AI_|ANTHROPIC_|GOOGLE_|XAI_|OPENROUTER_)" \
>   apps/frontman_server/envs/.dev.overrides.env | \
>   ssh root@DEVPOD_SERVER 'docker exec -i CONTAINER_NAME bash -c \
>     "cat >> /workspaces/BRANCH/apps/frontman_server/envs/.dev.overrides.env"'
>
> # 4. Fix DB_HOST if host.docker.internal doesn't resolve
> # The Docker gateway IP is typically 172.17.0.1 — verify with:
> ssh root@DEVPOD_SERVER 'docker exec CONTAINER_NAME awk '"'"'$2 == "00000000" { printf "%d.%d.%d.%d", "0x"substr($3,7,2), "0x"substr($3,5,2), "0x"substr($3,3,2), "0x"substr($3,1,2) }'"'"' /proc/net/route'
> # Update DB_HOST in both files:
> ssh root@DEVPOD_SERVER 'docker exec CONTAINER_NAME sed -i "s/DB_HOST=host.docker.internal/DB_HOST=172.17.0.1/" /workspaces/BRANCH/.env.devpod /workspaces/BRANCH/apps/frontman_server/envs/.dev.overrides.env'
>
> # 5. SSH into the workspace
> devpod ssh your-workspace
>
> # 6. Generate SSL certs (inside container)
> cd /workspaces/your-branch
> mkcert -install
> mkdir -p .certs
> mkcert -key-file .certs/frontman.local-key.pem -cert-file .certs/frontman.local.pem "*.frontman.local" frontman.local localhost
>
> # 7. Build workspace packages
> cd /workspaces/your-branch/libs/frontman-nextjs && yarn build && cd -
>
> # 8. Start dev servers
> # Phoenix needs env vars exported — op isn't available in the container,
> # so export secrets from the overrides file directly:
> cd /workspaces/your-branch/apps/frontman_server
> source ../../.env.devpod
> export $(grep -v "^#" envs/.dev.overrides.env | xargs)
> mix phx.server
>
> # Other servers (each in a separate terminal):
> cd /workspaces/your-branch && source .env.devpod
> make dev          # ReScript compiler
> make dev-client   # Vite (port 5173)
> make dev-nextjs   # Next.js (port 3000)
>
> # 9. Verify from your local machine (size_download should be > 0)
> curl -sSo /dev/null -w "HTTP %{http_code}, %{size_download} bytes\n" https://xxxx.nextjs.frontman.local/frontman
> curl -sSo /dev/null -w "HTTP %{http_code}, %{size_download} bytes\n" https://xxxx.api.frontman.local
> curl -sSo /dev/null -w "HTTP %{http_code}, %{size_download} bytes\n" https://xxxx.vite.frontman.local
> ```
> A healthy response has **size_download > 0**. If you see `HTTP 200, 0 bytes` Caddy isn't configured or the server isn't running.

### Creating New Feature Workspaces

There are two ways to create feature workspaces:

#### Option A: Containerized Worktree (Recommended)

Create a containerized worktree with Podman:

```bash
make wt-new BRANCH=issue-164
make wt-dev BRANCH=issue-164
```

#### Option B: Manual Steps

```bash
# 1. Create local worktree (optional, for local dev)
make worktree-create BRANCH=issue-164

# 2. Push branch to origin
cd .worktrees/issue-164 && git push -u origin issue-164

# 3. Create DevPod workspace
devpod up . --id issue-164 --source git:https://github.com/frontman-ai/frontman@issue-164
```

#### Option C: Direct from GitHub (no local worktree)

```bash
devpod up github.com/frontman-ai/frontman \
  --id new-feature \
  --source git:https://github.com/frontman-ai/frontman@feature/new-feature
```

Each workspace is isolated with its own:
- Git checkout
- Node modules
- Elixir deps
- Build artifacts

### Local Worktrees (Without DevPod)

For local-only development without the remote server:

```bash
# Create local worktree
make worktree-create BRANCH=my-feature

# Work in the worktree
cd .worktrees/my-feature
make install
make dev
```

Each worktree has an isolated `.claude/` directory for Claude Code context.

See `AGENTS.md` for more on the worktree workflow.

### Managing Workspaces

```bash
# List all workspaces
devpod list

# Stop a workspace (preserves state)
devpod stop my-feature

# Start a stopped workspace
devpod up my-feature

# Delete a workspace (removes container and data)
devpod delete my-feature
```

## Configuration for Remote Development

The following configuration changes enable services to work through the Caddy reverse proxy:

### Vite (`libs/client/vite.config.ts`)

```typescript
server: {
  host: "0.0.0.0",           // Bind to all interfaces
  port: 5173,
  allowedHosts: [".local"],  // Allow wt-*.local hostnames
  hmr: process.env.VITE_HMR_HOST
    ? {
        host: process.env.VITE_HMR_HOST,
        port: Number.parseInt(process.env.VITE_HMR_PORT || "443"),
        protocol: (process.env.VITE_HMR_PROTOCOL as "ws" | "wss") || "wss",
      }
    : true,
}
```

### Phoenix

Database hostname defaults to `localhost` in `config/dev.exs` and `config/test.exs`. For container environments (DevPod, CI), the `DB_HOST` env var overrides this at runtime via `config/runtime.exs`:

```elixir
# config/dev.exs — static default
config :frontman_server, FrontmanServer.Repo,
  hostname: "localhost",
  # ... other config

# config/runtime.exs — dynamic override for containers
if config_env() in [:dev, :test, :e2e] do
  db_host = env!("DB_HOST", :string, "localhost")
  if db_host != "localhost" do
    config :frontman_server, FrontmanServer.Repo, hostname: db_host
  end
end
```

This means:
- **Local dev**: `DB_HOST` unset → uses `localhost`
- **Local e2e**: `MIX_ENV=e2e` + `DB_HOST` unset → uses `localhost`
- **DevPod containers**: `DB_HOST=host.docker.internal` (or Docker gateway IP) → overrides hostname
- **CI**: `DB_HOST` resolved dynamically to the Docker gateway IP (see `.github/workflows/ci.yml`)

The endpoint binds to `0.0.0.0` and supports `PHX_HOST` override in `config/dev.exs`:

```elixir
config :frontman_server, FrontmanServerWeb.Endpoint,
  url: [
    host: System.get_env("PHX_HOST") || "frontman.local",
    port: String.to_integer(System.get_env("PHX_URL_PORT") || "4000"),
    scheme: "https"
  ],
  https: [
    ip: {0, 0, 0, 0},  # Bind to all interfaces
    # ... other config
  ]
```

### Environment Variables (`.env.devpod`)

The post-create script generates `.env.devpod` with worktree-specific URLs.
All variables use `export` so they are visible to child processes (e.g. `mix phx.server`):

```bash
# Example for worktree "issue-164" (hash: ea0c)
export WORKTREE_NAME=issue-164
export WORKTREE_ID=ea0c
export FRONTMAN_HOST=ea0c.api.frontman.local
export VITE_HMR_HOST=ea0c.vite.frontman.local
export VITE_HMR_PORT=443
export VITE_HMR_PROTOCOL=wss
export PHX_HOST=ea0c.api.frontman.local
export PHX_URL_PORT=443
export DB_HOST=host.docker.internal
```

### Secrets (`.dev.overrides.env`)

The post-create script creates `apps/frontman_server/envs/.dev.overrides.env` with DevPod-specific config (DB_HOST, PHX_HOST, PHX_URL_PORT). However, **secret keys (WORKOS, API keys) must be added separately**:

- **Via `make wt-new`**: Automatically copies secrets from your local `.dev.overrides.env` to the devpod
- **Manually**: SSH into the devpod and append keys to `apps/frontman_server/envs/.dev.overrides.env`

Required keys for auth to work:
```bash
WORKOS_API_KEY=sk_test_...
WORKOS_CLIENT_ID=client_...
```

## Database

PostgreSQL runs on the Docker host server and is shared across all workspaces.

- **Port:** 5432
- **Database:** `frontman_server_dev`
- **User:** `postgres`
- **Password:** `postgres`

Since PostgreSQL runs on the Docker host (not inside a container), containers must connect via the Docker gateway IP. The `DB_HOST` environment variable controls which hostname Phoenix uses to reach PostgreSQL:

| Environment | `DB_HOST` value | How it's set |
|---|---|---|
| Local dev | _(unset)_ → `localhost` | Default in `config/dev.exs` |
| DevPod container | `host.docker.internal` | Set in `.env.devpod` by post-create script |
| CI (self-hosted runner) | Docker gateway IP (e.g. `172.17.0.1`) | Resolved dynamically in `.github/workflows/ci.yml` |

If `host.docker.internal` doesn't resolve inside a container, use the Docker gateway IP instead:
```bash
# Find the gateway IP from inside a container
awk '$2 == "00000000" { printf "%d.%d.%d.%d", "0x"substr($3,7,2), "0x"substr($3,5,2), "0x"substr($3,3,2), "0x"substr($3,1,2) }' /proc/net/route
```

### Creating Additional Databases

If you need isolated databases per workspace:

```bash
# SSH into the server
ssh root@DEVPOD_SERVER

# Create a new database
sudo -u postgres createdb frontman_feature_xyz

# Then set DATABASE_URL in your workspace
export DATABASE_URL="postgres://postgres:postgres@host.docker.internal:5432/frontman_feature_xyz"
```

## Troubleshooting

### DNS Not Resolving

If `*.frontman.local` domains don't resolve:

```bash
# Check dnsmasq is running
sudo brew services list | grep dnsmasq

# Restart dnsmasq after config changes
sudo brew services restart dnsmasq

# Test resolution directly against dnsmasq
dig +short test.api.frontman.local @127.0.0.1

# Verify resolver files exist
ls /etc/resolver/*.frontman.local

# Flush macOS DNS cache
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

### Connection Issues

```bash
# Test SSH connection
ssh root@DEVPOD_SERVER 'echo "Connected!"'

# Check Docker is running on server
ssh root@DEVPOD_SERVER 'docker ps'

# Check DevPod provider configuration
devpod provider list
```

### Workspace Won't Start

```bash
# View workspace logs
devpod logs my-feature

# Rebuild the workspace
devpod up my-feature --recreate
```

### Services Return 200 But Empty Body (0 bytes)

Caddy returns HTTP 200 with `content-length: 0` when **no `.caddy` config exists** for the worktree hash. This is the most common issue after `devpod up` because Caddy registration is not automatic.

**Diagnosis:** Check if a config file exists:
```bash
ssh root@DEVPOD_SERVER 'ls /etc/caddy/worktrees/{hash}.caddy'
```

**Fix:** Create the Caddy config. Get the container IP first:
```bash
ssh root@DEVPOD_SERVER 'docker inspect CONTAINER_NAME --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'
```

Then create `/etc/caddy/worktrees/{hash}.caddy` using an existing file as template (e.g. copy another `.caddy` file, replace the hash and IP), and reload:
```bash
ssh root@DEVPOD_SERVER 'systemctl reload caddy'
```

If Caddy IS configured but you still get 0 bytes, the dev servers aren't running. SSH in and start them (see [Post-creation checklist](#accessing-services-via-browser)).

### Services Return 502 Bad Gateway

If Caddy returns 502, the service isn't reachable from the host. Common causes:

**Service not bound to 0.0.0.0:**
- Vite and Next.js must bind to all interfaces, not just localhost
- Check `libs/client/vite.config.ts` has `server.host: "0.0.0.0"`
- Next.js binds to 0.0.0.0 by default in dev mode

**Vite returns 403 Forbidden:**
Vite 7+ blocks requests from unknown hosts. The config must include:
```typescript
server: {
  host: "0.0.0.0",
  allowedHosts: [".local"],  // Allow *.local hostnames
}
```

### Phoenix Can't Connect to Database

If Phoenix shows `connection refused` or `nxdomain` for the database host:

1. **Check if `host.docker.internal` resolves inside the container:**
   ```bash
   # From inside the container
   getent hosts host.docker.internal
   ```

2. **If it doesn't resolve, find the Docker gateway IP:**
   ```bash
   # From inside the container — read gateway from /proc/net/route
   awk '$2 == "00000000" { printf "%d.%d.%d.%d\n", "0x"substr($3,7,2), "0x"substr($3,5,2), "0x"substr($3,3,2), "0x"substr($3,1,2) }' /proc/net/route
   ```

3. **Set `DB_HOST` to the gateway IP:**
   Add to `apps/frontman_server/envs/.dev.overrides.env`:
   ```
   DB_HOST=172.17.0.1
   ```
   Or add `host.docker.internal` to the container's `/etc/hosts`:
   ```bash
   ssh root@DEVPOD_SERVER "docker exec -u root CONTAINER_NAME bash -c \"echo '172.17.0.1 host.docker.internal' >> /etc/hosts\""
   ```

### Phoenix SSL Certificate Error

If Phoenix fails to start with SSL keyfile errors:

1. **Copy certs to container:**
   ```bash
   scp -r .certs root@DEVPOD_SERVER:/tmp/frontman-certs
   ssh root@DEVPOD_SERVER "docker cp /tmp/frontman-certs CONTAINER_NAME:/workspaces/WORKTREE/.certs"
   ssh root@DEVPOD_SERVER "docker exec -u root CONTAINER_NAME chown -R vscode:vscode /workspaces/WORKTREE/.certs"
   ```

2. **Or generate new certs in container:**
   ```bash
   docker exec CONTAINER_NAME bash -c 'cd /workspaces/WORKTREE && mkcert -install && mkcert -key-file .certs/frontman.local-key.pem -cert-file .certs/frontman.local.pem frontman.local localhost'
   ```

### Next.js Instrumentation Error

If Next.js crashes with Sentry/instrumentation errors:

```
TypeError: options.transport is not a function
```

Temporarily disable instrumentation:
```bash
mv test/sites/blog-starter/instrumentation.ts test/sites/blog-starter/instrumentation.ts.bak
rm -rf test/sites/blog-starter/.next
```

### Out of Disk Space

The biggest disk consumers are **GitHub Action runner writable layers** (yarn cache, mise installs, build artifacts accumulate ~5-7GB per runner per CI run) and **stale Docker build images**.

**Automated protections in place:**
- Runner work dirs are mounted as `tmpfs` (RAM-backed) so they don't persist to the overlay filesystem
- CI jobs clean up `node_modules` and build artifacts after each run
- Nightly cron (4:00 AM) prunes Docker, clears BuildKit cache, and restarts runners
- Weekly cron (Sunday 3:00 AM) removes all unused Docker images

**Manual cleanup if needed:**

```bash
# Check disk usage
ssh root@DEVPOD_SERVER 'df -h / && docker system df'

# Clear BuildKit cache (separate from docker system prune)
ssh root@DEVPOD_SERVER 'docker buildx prune -a -f'

# Restart runners to clear any writable layer bloat
ssh root@DEVPOD_SERVER 'cd /home/github-runner && docker compose -f docker-compose.ci.yml down && docker compose -f docker-compose.ci.yml up -d'

# Remove stale build images
ssh root@DEVPOD_SERVER 'docker images --filter "reference=frontman-*" -q | xargs -r docker rmi -f'

# Nuclear option — remove everything (requires rebuilding all workspaces)
ssh root@DEVPOD_SERVER 'docker system prune -a --volumes -f && docker buildx prune -a -f'
```

## Server Maintenance

### Checking Server Status

```bash
ssh root@DEVPOD_SERVER << 'EOF'
echo "=== Docker ==="
docker ps

echo ""
echo "=== PostgreSQL ==="
systemctl status postgresql | head -5

echo ""
echo "=== Disk Usage ==="
df -h /

echo ""
echo "=== Memory ==="
free -h
EOF
```

### Updating the Server

```bash
ssh root@DEVPOD_SERVER << 'EOF'
apt update && apt upgrade -y
docker system prune -f
EOF
```

## Resource Limits

The CX33 server has:
- 8 shared vCPUs
- 8GB RAM + 4GB swap
- 80GB NVMe SSD

Estimated usage per workspace:
- ~1.5-2GB RAM (with all dev servers running)
- ~5-10GB disk (deps, node_modules, build artifacts)

**Recommended:** Run 1-2 concurrent workspaces comfortably (CI runners consume ~7.5GB when active).

## Security Notes

1. **SSH Key Auth:** Password authentication should be disabled after initial setup
2. **Firewall:** Only SSH (port 22) and HTTPS (port 443) are exposed
3. **Database:** PostgreSQL only accepts connections from Docker network and localhost
