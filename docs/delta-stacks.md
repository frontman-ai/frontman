# Local Delta checkout stacks

Each physical checkout has a separate Podman pod. Its identity is the first
12 SHA-256 characters of its canonical checkout path, not its Git branch.
The checkout itself is mounted at `/workspaces/frontman`; no nested Git worktree
is created. Moving a checkout creates a new identity. Remove its old stack first.
The dev container also mounts the checkout at its original path, read-only.
Git metadata mounts are read-only and retain their original paths.
These mounts support Delta checkouts whose Git configuration contains absolute paths.

## Prerequisites

- Linux with rootless Podman, Python 3, `getent`, `sha256sum`, `curl`, and authenticated `op`.
- Build `frontman-dev:latest` with `make infra-build`.
- Install mkcert through the repository's mise configuration.
  Use the host CA already trusted by `make ssl-setup`.
  Stack commands never install a CA or change the host trust store.
- Configure wildcard `*.frontman.local` DNS to IPv4 `127.0.0.1` (IPv6-only
  resolution is not supported by this stack's loopback port binding). The existing
  `infra/local/dnsmasq-setup.sh` is a host-admin operation; inspect it first.
- Unlock the 1Password account used by
  `apps/frontman_server/envs/.dev.secrets.env`. The Stripe development key must
  support Stripe CLI webhook forwarding.
- Internet access for images, mise tools, JS/Elixir dependencies and Composer.

`make delta-preflight` checks Podman, the dev image, `op` availability, DNS, and host mkcert CA trust.
It does not check vault authentication, browser-specific trust stores, or WorkOS configuration.
It creates nothing.

The executable `.agents/prepare` runs `make prepare-deps`, not the stack preflight.
It fetches locked JS workspace and server dependencies without application builds, databases, secrets, or containers.
Yarn uses a shared download cache and checkout-local dependencies.
Mix uses its normal package cache and checkout-local server dependencies.
Hex and Rebar install only when missing.
Dependency install scripts can run, but the hook does not start services.

The hook requires mise and the pinned Node, Yarn, Erlang, and Elixir tools.
Before the first run, run `mise trust` for this checkout and install the missing pinned tools explicitly.
The hook does not install the toolchain or accept trust prompts.
Cold downloads take longer than repeat runs.
Container setup still uses separate dependency volumes and requires `make delta-prepare`.

## Lifecycle

### Recommended: a Delta background terminal

Prepare each new checkout once:

```sh
make delta-prepare
```

Then open a terminal in the thread by typing `!` at the start of an empty composer line.
Run this command:

```sh
make delta-dev
```

Enable **Background Mode** on that terminal before you send the message.
On Linux, its shortcut is Ctrl+Alt+Z.
The command remains active and owns the stack until you stop it.
Use **Background Terminals → Stop Process** to end the session without deleting its data.
Ctrl+C in the terminal also ends the session.

One foreground session can own a stack at a time.
While it runs, commands that start, prepare, replace, or remove the stack refuse to proceed.
Stop the foreground session before you use those commands.
Status, URLs, checks, and logs remain available.

An independent watchdog tracks the foreground process and its parent.
It stops the exact pod if either process exits, including after forced termination.
The watchdog retains its cleanup code in memory, so checkout removal does not remove the cleanup instructions.
This protection requires the watchdog to remain alive and Podman to remain available.
It cannot guarantee cleanup if the watchdog itself receives SIGKILL.
Cleanup retains ownership and retries if Podman reports an operational error.
Foreground output uses an anonymous log spool that is truncated when it exceeds 1 MiB.
The spool disappears when its processes exit.

Delta documents terminal shutdown when the app quits or the thread is removed.
It does not explicitly equate thread removal with archiving.
Closing a tab or switching threads is not a stop command.
See the [Delta terminal guide](https://delta.dev/docs/agents/terminals#manage-background-terminals).

### Detached mode and inspection

Use `make delta-up` only when the stack must continue independently of a Delta terminal.
This command returns after readiness checks. It does not connect container shutdown to the terminal lifecycle.

```sh
make delta-up                     # deliberately detached; alias: delta-start
make delta-status
make delta-urls
make delta-logs                   # SERVICE=wordpress, proxy, db, or pg
make delta-check
make delta-stop
```

Prepare creates the pod, installs dependencies, builds the integrations, standalone
client and preview bridge, migrates PostgreSQL, builds the scoped PHP vendor
dependencies, installs WordPress, and activates the current checkout's plugin.
It returns after setup. Up starts a background process supervisor.
Up polls the service endpoints and client assets for up to 180 seconds.
It returns an error if the supervisor stops or the endpoints remain unavailable.
A failed dev process terminates its siblings.
If startup fails, inspect `make delta-logs` before you retry.
After changing dependencies or migrations, rerun prepare with the stack stopped.
Do not run prepare concurrently with a development session or another prepare.
After a container restart, startup removes supervisor and ReScript watcher locks that predate that container session.

PostgreSQL, MariaDB, WordPress files (including uploads and installed plugins),
tool home, node modules, Elixir dependencies/builds, and internal Phoenix certificates
use checkout-specific named volumes. Stop preserves them. The current plugin
source is read-only inside WordPress; edit it in the checkout. Generated preview
assets and scoped vendor files are built in the checkout using existing targets.
WordPress uses the standalone client, rebuilt in watch mode and served by Vite
from `dist` with its extracted CSS. Browser refresh loads changes; this bundle
does not use Vite React hot reload. Next and Astro retain the existing development
integration's Vite source entrypoint, which imports CSS through Vite.
The preview bridge is a separate generated bundle, not watched automatically.
After changing `libs/frontman-preview-bridge`, run `make delta-preview` and refresh
the WordPress preview. This rebuilds and copies the bridge through the existing
`build-wordpress-preview` target inside the dev container.

The pod exposes only one dynamically assigned loopback HTTPS port. Its own Caddy
routes the five service hostnames; existing `worktree-*` pods and the shared
`frontman-caddy` config are never changed. The port persists across stop/start,
but changes after destructive recreation.

### TLS and login

The proxy uses a certificate signed by your existing host mkcert CA.
Each certificate covers the five service hostnames for its checkout.
The certificate and server key stay in the ignored `.certs/delta` directory.
Caddy mounts that directory read-only. The CA private key stays on the host and never enters a container.

New stacks generate their certificate during preparation.
Startup renews certificates that expire within seven days, lack a service hostname, or use a different CA.
No per-stack certificate import is necessary when your browser already trusts the host mkcert CA.

For an existing stack that used a private Caddy CA, run `make delta-tls`.
This command checks the new proxy configuration before replacing only the proxy container.
The pod, service port, databases, and WordPress content remain unchanged.
`make delta-check` uses normal curl certificate validation, without `--insecure`.
The internal Phoenix connection retains its separate container-local certificate.

Use `delta-urls` to obtain the Phoenix URL. Add that origin and
`/auth/callback` callback to your development WorkOS application as required
by its settings. A new port requires updated allowlists. Login is not validated
by preflight or the HTTP smoke check. Do not use a production WorkOS application.

WordPress admin username is `admin`; retrieve its random local password with:

```sh
podman exec delta-frontman-IDENTITY-wordpress cat /var/lib/frontman/admin-password
```

Open WordPress `/wp-admin/`, then `/index.php/frontman` (the initial site uses
plain permalinks). The runtime check renders the real plugin page as admin and
asserts that its client, CSS and Phoenix host all reference this checkout.
The generated admin password stays in a private volume outside the web root.
Preparation migrates the password file from older stacks and removes the old web-root file.
Older WordPress containers need the private state volume mounted at `/var/lib/frontman` before preparation.
Preserve their existing WordPress and database volumes when replacing the container.

Resolved 1Password values are passed directly to Podman, never written to the
checkout. Like ordinary container environment variables, they are visible to
the local container owner via inspection. Stripe webhook credentials and
runtime env copies live in container `/tmp`. Recreate the pod to refresh its
1Password values. Do not commit or share container inspection output.

The listener uses the existing development Stripe account.
Separate databases do not isolate Stripe events: each listener can receive events from other checkouts on that account.
Separate Stripe sandboxes are necessary for independent billing tests.

### Destructive removal

```sh
make delta-remove CONFIRM=delta-frontman-IDENTITY
```

This removes the pod and all its named volumes, including both databases,
uploads, installed plugins, and container credentials. It never removes the checkout or host mkcert CA.
Without the exact confirmation value, removal refuses to proceed.
Removal also works when a failed creation already removed the pod but left its volumes.
You can repeat an interrupted removal with the same confirmation.

## Validation

`make delta-syntax` checks shell syntax without provisioning anything.
`make delta-test-processes` starts real shell children and grandchildren and
checks that supervisor cleanup terminates their entire process group.
It also checks that early service exits stop siblings during builds, bundle readiness, and normal operation.
`make delta-test-lifecycle` uses disposable Podman pods and persistent volume sentinels.
It checks TERM, HUP, process-group termination, owner SIGKILL, parent SIGKILL, and checkout removal.
Each scenario also checks duplicate-owner rejection, unrelated-pod isolation, and volume preservation.
It does not automate Delta's Stop Process, Stop All, archive, or app-exit controls.
`make delta-test-cleanup` uses disposable pods to check stale supervisor PIDs and failed graceful shutdown.
It also checks removal with an absent pod, partial volumes, repeated removal, and confirmation enforcement.
`make delta-check` requires a prepared, running stack. It uses the same readiness
poll as `make delta-up`, including client JavaScript, CSS, and preview-bridge assets.
The asset checks require nonempty responses with the expected content types.
It also checks WordPress activation and the local URLs in the rendered Frontman page.
It does not exercise OAuth, model calls, or browser UI.
For Next.js preview routing, set `NEXTJS_URL` to the Next.js URL from `make delta-urls`.
Run `make -C test/sites/blog-starter test-preview` against the running stack.
This checks root and nested-page entrypoints, with and without trailing slashes.
For isolation validation, prepare two checkouts and compare identities, mounts,
URLs and WordPress content; stop/start one and confirm its content persists.
