# Microsandbox Dev Environment

**Date:** 2026-04-10  
**Status:** Approved

## Overview

Replace the current Podman-based containerized worktree system with microsandbox microVMs. Each sandbox is a fully self-contained environment: a full git clone of the repo, the toolchain, and a Postgres instance — all inside a single hardware-isolated VM. The workflow is agent-driven: the agent works entirely inside the sandbox via exec commands.

## Goals

- Drop Podman, git worktrees, Caddy, and dnsmasq
- Single VM per named sandbox (no multi-container pod concept)
- Agent-exec model: all code edits, git operations, and test runs happen inside the VM
- Architecture that maps cleanly to a future hosted/cloud version
- Simpler onboarding: `make infra-up` is a health check, not a multi-step infra setup

## Non-Goals

- Provider abstraction layer (intentionally deferred — swap `bin/sandbox` internals when needed)
- Remote/hosted sandboxes (local only for now)
- Caddy URL routing (direct `localhost:PORT` is sufficient)

## Architecture

```
Host machine
├── Makefile (sb-* targets)
└── bin/sandbox              ← single TypeScript file, microsandbox Node SDK

Per-sandbox microVM
├── /workspaces/frontman     ← full git clone, agent checks out branch inside
├── PostgreSQL               ← running as a service inside the VM
├── node_modules             ← named volume (persists across stop/start)
├── mix deps                 ← named volume
├── mix _build               ← named volume
└── toolchain                ← from frontman-dev OCI image (Elixir + Node + Postgres)
```

## `bin/sandbox` Script

Single TypeScript file executed via `tsx`. Replaces all `bin/wt-pod-*` scripts and `bin/pod-exec`.

### Commands

| Command | Description |
|---|---|
| `create <name>` | Create VM, clone repo, install deps, start Postgres |
| `start <name>` | Resume a stopped sandbox |
| `stop <name>` | Pause sandbox (named volumes preserved) |
| `exec <name> -- <cmd...>` | Run a command inside the sandbox |
| `shell <name>` | Interactive shell into the sandbox |
| `remove <name>` | Full cleanup: sandbox + named volumes |
| `list` | Show all frontman sandboxes with status |

### Sandbox Naming

Sandboxes are named freely (`issue-123`, `feature-foo`, etc.) — no branch coupling. The sandbox name drives the hash for deterministic port assignment.

```
hash = md5(<name>)[0:4]
sandbox_name = frontman-<hash>
```

### Named Volumes

| Volume name | Mount path inside VM |
|---|---|
| `frontman-<hash>-node-modules` | `/workspaces/frontman/node_modules` |
| `frontman-<hash>-mix-deps` | `/workspaces/frontman/apps/frontman_server/deps` |
| `frontman-<hash>-mix-build` | `/workspaces/frontman/apps/frontman_server/_build` |
| `frontman-<hash>-pgdata` | `/var/lib/postgresql/data` |

## Setup Flow (`create`)

1. Resolve secrets on the host via `op run` — extract relevant env vars
2. Call `Sandbox.create()` with:
   - Dev OCI image
   - Named volumes mounted
   - Deterministic port mappings
   - Secrets + `SANDBOX_NAME` + `PORT_*` as env vars
3. Inside VM via `sb.shell()`:
   - Start Postgres service and create database user
   - Clone repo using `GITHUB_TOKEN` from env
   - `yarn install`
   - `mix deps.get`
   - `mix ecto.setup`
4. Sandbox is idle, ready for agent exec commands

## Port Scheme

Same deterministic formula as the old worktree system — no Caddy, direct `localhost:PORT` access:

```
base = (0xHASH % 5000) + 10000
Phoenix:   base + 0
Vite:      base + 1
Next.js:   base + 2
Marketing: base + 4
```

## OCI Image

The existing `frontman-dev` Dockerfile is extended to include PostgreSQL. Image is built locally with Podman — no registry push required. If microsandbox requires a local registry to consume locally-built images, a `localhost:5000` registry is used (implementation detail to verify during build).

## Makefile Targets

| New target | Replaces | Description |
|---|---|---|
| `sb-new NAME=...` | `wt-new BRANCH=...` | Create sandbox + clone + setup |
| `sb-start NAME=...` | `wt-start BRANCH=...` | Resume paused sandbox |
| `sb-stop NAME=...` | `wt-stop BRANCH=...` | Pause sandbox |
| `sb-sh NAME=...` | `wt-sh BRANCH=...` | Interactive shell |
| `sb-exec NAME=... CMD=...` | `bin/pod-exec` | Run command in sandbox |
| `sb-rm NAME=...` | `wt-rm BRANCH=...` | Full cleanup |
| `sb-ls` | `wt` | List all sandboxes |
| `infra-build` | `infra-build` | Build dev OCI image locally |
| `infra-up` | `infra-up` | Verify msb installed + image built |
| `infra-down` | `infra-down` | Remove all frontman sandboxes |

**Removed targets:** `wt-dev`, `wt-urls`, `wt-gc`, `wt-logs` — dev server lifecycle moves inside the sandbox; agents don't need a dashboard or URL routing.

## Backwards Compatibility

`bin/pod-exec` is kept as a shim calling `tsx bin/sandbox exec` for any scripts referencing it, but marked deprecated in CLAUDE.md.

## Files Changed

| File | Action |
|---|---|
| `bin/sandbox` | New — TypeScript, replaces all bin/wt-pod-* |
| `bin/pod-exec` | Updated — thin shim to bin/sandbox exec |
| `bin/wt-pod-create` | Deleted |
| `bin/wt-pod-dev` | Deleted |
| `bin/wt-pod-remove` | Deleted |
| `bin/wt-resolve` | Deleted |
| `bin/wt-dashboard` | Deleted |
| `bin/wt-gc` | Deleted |
| `infra/local/` | Deleted — Caddy/dnsmasq infra |
| `.devcontainer/Dockerfile` | Updated — add Postgres |
| `Makefile` | Updated — sb-* targets, simplified infra-* |
| `CLAUDE.md` | Updated — document sb-* workflow, remove worktree section |

## Secrets

Resolved at sandbox creation time via `op run --env-file=apps/frontman_server/envs/.dev.secrets.env`. The resolved env vars (filtered to relevant prefixes) are passed directly to `Sandbox.create()` as the `env` option. They never touch disk on the host.

`GITHUB_TOKEN` is required for cloning the repo inside the VM. It must be added as an `op://` reference to `.dev.secrets.env` (or a separate secrets file) so it is resolved by `op run` alongside the other secrets.
