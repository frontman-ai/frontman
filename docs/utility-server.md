# Utility Server (Hetzner)

The Hetzner cloud server (CX33: 8 vCPU, 8GB RAM, 80GB NVMe + 4GB swap) serves dual purpose:

1. **CI Runners** — Self-hosted GitHub Actions runners for the repo
2. **DevPod Workspaces** — Remote development environments (see [remote-development.md](./remote-development.md))

The server IP is stored in 1Password and referenced via the root `.env` file as `DEVPOD_SERVER`:

```bash
# Resolve the IP
op read "op://frontman/DEVPOD_SERVER/password"

# SSH in
ssh root@<DEVPOD_SERVER>
```

## CI Runners

Self-hosted GitHub Actions runners are managed via Docker Compose on the server.

### Configuration

The compose file lives at `/home/github-runner/docker-compose.ci.yml` on the server. Each runner is a container using the `myoung34/github-runner:ubuntu-noble` image with ephemeral mode enabled.

The `GITHUB_RUNNER_TOKEN` env var is loaded from the environment (set in the shell profile on the server).

### Changing the number of runners

Edit the compose file on the server:

```bash
ssh root@<DEVPOD_SERVER>
vi /home/github-runner/docker-compose.ci.yml
```

Each runner is a separate service block (`runner-1`, `runner-2`, etc.). To add/remove runners, duplicate or remove service blocks and adjust:

- Service name: `runner-N`
- `RUNNER_NAME`: `hetzner-runner-N`
- Resource limits (split CPU/memory evenly across runners, leaving headroom for the OS and DevPod)

Then apply:

```bash
cd /home/github-runner
docker compose -f docker-compose.ci.yml up -d
```

### Current configuration (3 runners)

| Resource | Per runner | Total (3 runners) |
|----------|-----------|-------------------|
| CPU | 2.5 vCPU | 7.5 / 8 vCPU |
| Memory | 2.5 GB | 7.5 / 8 GB |

The server also has 4 GB swap as an OOM safety net.

### Useful commands

```bash
# SSH into the server
ssh root@<DEVPOD_SERVER>

# Check runner status
docker ps --format "table {{.Names}}\t{{.Status}}" | grep runner

# View logs for a specific runner
cd /home/github-runner
docker compose -f docker-compose.ci.yml logs runner-1

# Restart all runners
cd /home/github-runner
docker compose -f docker-compose.ci.yml restart

# Pull latest runner image and recreate
cd /home/github-runner
docker compose -f docker-compose.ci.yml pull
docker compose -f docker-compose.ci.yml up -d
```
