# Remote Development with DevPod

This guide explains how to use DevPod to run Frontman development environments on a remote Hetzner server.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Hetzner Cloud Server (77.42.16.199)                                    │
│  CX43: 8 vCPU, 16GB RAM, 160GB NVMe                                     │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Caddy Reverse Proxy (ports 80/443)                             │    │
│  │  Routes: wt-{hash}-{service}.local → container IP               │    │
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
          │ SSH Tunnel (ports 8080→80, 8443→443)
          ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  Your Local Machine                                                     │
│  - /etc/hosts: ea0c.nextjs.frontman.local → 127.0.0.1                   │
│  - Browser: https://ea0c.nextjs.frontman.local:8443/__frontman          │
│  - All services accessible via subdomains                               │
└─────────────────────────────────────────────────────────────────────────┘
```

## URL Scheme

Each worktree gets a unique 4-character hash ID based on its name. URLs follow this format for WorkOS OAuth compatibility:

```
https://{hash}.{service}.frontman.local:8443
```

| Worktree | Hash | Next.js URL | Vite URL | Phoenix URL |
|----------|------|-------------|----------|-------------|
| issue-164 | ea0c | https://ea0c.nextjs.frontman.local:8443 | https://ea0c.vite.frontman.local:8443 | https://ea0c.api.frontman.local:8443 |
| issue-189 | b09b | https://b09b.nextjs.frontman.local:8443 | https://b09b.vite.frontman.local:8443 | https://b09b.api.frontman.local:8443 |

Services per worktree:
- `{hash}.nextjs.frontman.local` - Next.js dev server (port 3000) - access at `/__frontman`
- `{hash}.vite.frontman.local` - Vite client dev server (port 5173)
- `{hash}.api.frontman.local` - Phoenix server (port 4000)
- `{hash}.storybook.frontman.local` - Storybook (port 6006)

**Important:** The URL format `{hash}.{service}.frontman.local` is required for WorkOS OAuth redirects to work correctly. WorkOS needs consistent redirect URIs, and this subdomain pattern allows multiple development environments while maintaining OAuth compatibility.

## Prerequisites

- SSH key configured (already done if you can `ssh root@77.42.16.199`)
- DevPod CLI installed locally
- mkcert installed locally (`brew install mkcert`)

## Quick Start

```bash
# 1. Add hosts entries (one-time)
make worktree-hosts | sudo tee -a /etc/hosts

# 2. Start SSH tunnel (keep running in a terminal)
make tunnel

# 3. Get URLs for your worktree
make worktree-urls BRANCH=issue-164
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

### 2. Add Hetzner Server as SSH Provider

```bash
# Add the SSH provider with our Hetzner server
devpod provider add ssh --option HOST=root@77.42.16.199
```

### 3. Create Your First Workspace

```bash
# Create a workspace from the main branch
devpod up github.com/YOUR_ORG/frontman --branch main --id main

# Or from a feature branch
devpod up github.com/YOUR_ORG/frontman --branch feature/my-feature --id my-feature
```

This will:
1. Clone the repo on the remote server
2. Build the devcontainer image
3. Install all runtimes (Node.js, Elixir, etc.) via mise
4. Run `make install` to get dependencies
5. Set up SSH tunneling for all ports

### 4. Connect Your IDE

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

**On your local machine**, ensure the SSH tunnel is running:

```bash
# In a separate terminal, keep this running
make tunnel
```

Then access services via their subdomains (get URLs with `make worktree-urls BRANCH=your-branch`):

- `https://xxxx.nextjs.frontman.local:8443/__frontman` - Next.js (Frontman UI)
- `https://xxxx.vite.frontman.local:8443` - Vite client
- `https://xxxx.api.frontman.local:8443` - Phoenix server
- `https://xxxx.storybook.frontman.local:8443` - Storybook

The services are routed through Caddy reverse proxy on the server, which handles SSL termination with locally-trusted certificates.

### Creating New Feature Workspaces

There are two ways to create feature workspaces:

#### Option A: One Command (Recommended)

Use the integrated Makefile command that creates a local worktree, pushes the branch, and sets up DevPod:

```bash
make worktree-devpod BRANCH=issue-164
```

This will:
1. Create a local worktree at `.worktrees/issue-164/`
2. Push the branch to origin
3. Create a DevPod workspace on the remote server
4. Print connection instructions

#### Option B: Manual Steps

If you prefer more control:

```bash
# 1. Create local worktree (optional, for local dev)
make worktree-create BRANCH=issue-164

# 2. Push branch to origin
cd .worktrees/issue-164 && git push -u origin issue-164

# 3. Create DevPod workspace
devpod up . --branch issue-164 --id issue-164
```

#### Option C: Direct from GitHub (no local worktree)

```bash
devpod up github.com/YOUR_ORG/frontman \
  --branch feature/new-feature \
  --id new-feature
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
        port: Number.parseInt(process.env.VITE_HMR_PORT || "8443"),
        protocol: (process.env.VITE_HMR_PROTOCOL as "ws" | "wss") || "wss",
      }
    : true,
}
```

### Phoenix (`apps/frontman_server/config/dev.exs`)

```elixir
# Database - supports container development via DB_HOST env var
config :frontman_server, FrontmanServer.Repo,
  hostname: System.get_env("DB_HOST") || "localhost",
  # ... other config

# Endpoint - binds to 0.0.0.0 and supports PHX_HOST override
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

The post-create script generates `.env.devpod` with worktree-specific URLs:

```bash
# Example for worktree "issue-164" (hash: ea0c)
WORKTREE_NAME=issue-164
WORKTREE_ID=ea0c
FRONTMAN_HOST=ea0c.api.frontman.local:8443
VITE_HMR_HOST=ea0c.vite.frontman.local
VITE_HMR_PORT=8443
VITE_HMR_PROTOCOL=wss
PHX_HOST=ea0c.api.frontman.local
DB_HOST=host.docker.internal
```

## Database

PostgreSQL runs on the host server and is shared across all workspaces.

- **Host:** `host.docker.internal` (from inside containers)
- **Port:** 5432
- **Database:** `frontman_server_dev`
- **User:** `postgres`
- **Password:** `postgres`

The `DB_HOST` environment variable must be set to `host.docker.internal` for Phoenix to connect from inside the container.

### Creating Additional Databases

If you need isolated databases per workspace:

```bash
# SSH into the server
ssh root@77.42.16.199

# Create a new database
sudo -u postgres createdb frontman_feature_xyz

# Then set DATABASE_URL in your workspace
export DATABASE_URL="postgres://postgres:postgres@host.docker.internal:5432/frontman_feature_xyz"
```

## Troubleshooting

### Connection Issues

```bash
# Test SSH connection
ssh root@77.42.16.199 'echo "Connected!"'

# Check Docker is running on server
ssh root@77.42.16.199 'docker ps'

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

### Port Forwarding Not Working

DevPod handles port forwarding automatically. If ports aren't accessible:

```bash
# Check which ports are forwarded
devpod status my-feature

# Manually forward a port
devpod ssh my-feature -- -L 4000:localhost:4000
```

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

If Phoenix shows `connection refused` to PostgreSQL:

1. **Add host.docker.internal to container:**
   ```bash
   # Get host gateway IP
   HOST_IP=$(ssh root@77.42.16.199 "ip route | grep default | awk '{print \$3}'")
   
   # Add to container's /etc/hosts
   ssh root@77.42.16.199 "docker exec -u root CONTAINER_NAME bash -c \"echo '\$HOST_IP host.docker.internal' >> /etc/hosts\""
   ```

2. **Set DB_HOST environment variable:**
   Add to `apps/frontman_server/envs/.dev.env`:
   ```
   DB_HOST=host.docker.internal
   ```

### Phoenix SSL Certificate Error

If Phoenix fails to start with SSL keyfile errors:

1. **Copy certs to container:**
   ```bash
   scp -r .certs root@77.42.16.199:/tmp/frontman-certs
   ssh root@77.42.16.199 "docker cp /tmp/frontman-certs CONTAINER_NAME:/workspaces/WORKTREE/.certs"
   ssh root@77.42.16.199 "docker exec -u root CONTAINER_NAME chown -R vscode:vscode /workspaces/WORKTREE/.certs"
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

```bash
# SSH into server and clean Docker
ssh root@77.42.16.199 'docker system prune -a'

# Check disk usage
ssh root@77.42.16.199 'df -h'
```

## Server Maintenance

### Checking Server Status

```bash
ssh root@77.42.16.199 << 'EOF'
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
ssh root@77.42.16.199 << 'EOF'
apt update && apt upgrade -y
docker system prune -f
EOF
```

## Resource Limits

The CX43 server has:
- 8 shared vCPUs
- 16GB RAM
- 160GB NVMe SSD

Estimated usage per workspace:
- ~1.5-2GB RAM (with all dev servers running)
- ~5-10GB disk (deps, node_modules, build artifacts)

**Recommended:** Run 3-5 concurrent workspaces comfortably.

## Security Notes

1. **SSH Key Auth:** Password authentication should be disabled after initial setup
2. **Firewall:** Only SSH (port 22) is exposed; all other ports are tunneled
3. **Database:** PostgreSQL only accepts connections from Docker network and localhost
