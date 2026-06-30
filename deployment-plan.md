# Safe Deployment And Draining Plan

## Goal

Blue/green deploy with real drain, built on OTP ownership first:

- Runtime supervision owns execution lifetime and terminal events.
- New traffic moves to the new slot only after readiness succeeds.
- Old slot keeps existing executions alive after traffic moves away.
- Old slot stops only after active work drains or timeout.
- New agent runs are never rejected because of drain state.
- No process that needs `FrontmanServer.Repo` can outlive `Repo` during shutdown.
- Overall change is net-negative lines of code by deleting duplicated deploy logic and raw death watcher code.

## Non-Goals

- No queueing user requests in the app.
- No app-level "draining means reject agent run" behavior.
- No admin UI.
- No broad orchestration framework.
- No Kubernetes-style abstractions unless deployment moves there.
- No defensive Repo-unavailable fallback as substitute for correct supervision order.

## Design Principles

- Drain is a routing concern.
- Execution lifetime is an OTP concern.
- Persistence availability is a supervision-order concern.
- Deploy scripts should switch traffic and ask the runtime for quiescence; they should not own process lifecycle semantics.
- Runtime state used for deploy decisions must be derived from supervised execution ownership, not bolted on globally.

## Target Deploy Flow

```text
1. Deploy release to inactive slot.
2. Start inactive slot.
3. Wait inactive /ready == 200.
4. Mark active slot draining.
5. Reload Caddy to route new traffic to inactive slot.
6. Poll old active slot runtime status until active work == 0 or timeout.
7. systemctl stop old active slot.
```

## Key Design

- `/health`: liveness, process alive.
- `/ready`: readiness, receives new traffic only when not draining.
- Drain state controls routing eligibility only.
- Active work tracking controls stop timing.
- OTP supervision controls execution lifetime and terminal event emission.
- `Repo` remains a dependency that stops after clients that need it.

## Current Status

Completed:

- Deliverable 1: locked current execution terminal semantics with tests.
- Deliverable 2: replaced raw death watcher with supervised `SwarmAi.Runtime` monitor.
- Deliverable 3: added `SwarmAi.active_count/1` with deploy polling as first production caller.
- Deliverable 4: split `/health` and `/ready`; readiness has no DB dependency.
- Deliverable 5: added supervised `FrontmanServer.Drain` and wired `/ready` to drain readiness.
- Deliverable 6: added `FrontmanServer.Drain.status/0` with deploy polling as first production caller.
- Deliverable 7: added release RPC drain command and deploy-script callers.
- Deliverable 8: deploy and rollback readiness checks now use `/ready`.
- Deliverable 9: consolidated blue/green deploy logic so `build-and-deploy.sh` builds then calls canonical `deploy.sh`.
- Deliverable 10: replaced fixed `sleep 5` with execution drain wait.
- Deliverable 11: aligned Bandit HTTP shutdown timeout and systemd stop timeout.
- Deliverable 12: skipped because expected termination is already non-noisy after OTP monitor changes.
- Deliverable 13: added runtime drain-entry log; deploy already logs count, completion, and timeout.
- Deliverable 14: deferred because no deploy data proves connection-level drain is needed.

PR / review status:

- PR opened: https://github.com/frontman-ai/frontman/pull/1213
- Automated review found two valid P1 deploy-script issues; both fixed and review threads resolved.
- Changelog CI initially failed because changeset referenced non-workspace package `frontman`; fixed by changing the changeset to empty frontmatter.
- Current CI after review fix: changelog/build/client-side/Elixir checks passed; E2E was still pending at last local check.
- Local commits are unsigned because local 1Password SSH signing failed with `failed to fill whole buffer`; hooks still passed.

Deferred by policy:

- None.

Next likely work:

- Review deploy changes end-to-end before merging or shipping.

## What We Learned

- Do not add production APIs only to satisfy tests. Production API must have a production caller in the same change.
- `SwarmAi.active_count/1` is valid design, but premature until deploy polling consumes it.
- `FrontmanServer.Drain.status/0` is valid design, but premature until deploy polling consumes it.
- Split drain state safely by first adding `ready?/0` because `/ready` was its production caller, then adding `start_draining/0` only when deploy scripts called it through release RPC.
- `stop_draining/0` is unnecessary right now because inactive slot restart starts `Drain` in ready state, and no production caller needs to clear drain state in a running node.
- `:api` router pipeline is correct for `/health` and `/ready`: deploy/proxy checks need JSON without browser session, auth, or CSRF.
- Boundary exports matter: web layer can call `FrontmanServer.Drain` only after it is exported by the `FrontmanServer` boundary.
- `HealthController.ready/2` must not query `Repo`; readiness is routing eligibility, not database health.
- Local verification can fail for environmental reasons when app boot starts Oban and Postgres is unavailable; once DB/app boot was available, focused drain/health tests passed.
- Killing the supervised `Drain` process in tests destabilized later tests. Test-only state reset should use OTP test tools like `:sys.replace_state/2`, not production reset APIs.
- `build-and-deploy.sh` duplicated too much deploy behavior. Making `deploy.sh` canonical removed the main divergence risk and cut `build-and-deploy.sh` from 211 lines to 89 lines.
- Rollback should use readiness too. A rollback target that is alive but draining is not eligible for new traffic.
- Release RPC uses `RELEASE_NODE` and `RELEASE_COOKIE` from the environment. Because blue/green slot env files are slot-specific, deploy scripts must source the env for the slot they are RPCing, not rely on whatever env was sourced last.
- Migration env sourcing must not leak into later deploy steps. Running migrations inside a subshell prevents inactive-slot `RELEASE_NODE` / `RELEASE_COOKIE` from accidentally targeting later active-slot RPCs at the new slot.
- First rollout of the drain-capable deploy script runs while the active slot is still an old release that does not define `FrontmanServer.Drain`. Drain RPC and drain-status polling must tolerate that one-time bootstrap case.
- First-rollout fallback should preserve safety by switching traffic to the ready new slot, skipping active-execution wait only when the old active release cannot report drain status, and stopping the old slot as previous deploys did.
- Warnings emitted inside command substitution must go to stderr if stdout is parsed as a value. `active_execution_count` prints fallback warnings to stderr so stdout remains numeric.
- Empty changeset frontmatter is valid for non-workspace infrastructure/app changes when CI only needs evidence that the changelog check was considered; naming a non-workspace package breaks `yarn changeset status`.
- `gh pr view --json comments,reviews` does not include inline review threads. Use GitHub GraphQL `reviewThreads` to fetch, reply to, and resolve inline review comments.

## Deliverable 1: Lock Current Execution Terminal Semantics

Status: Complete.

Description: Add tests that capture current execution terminal event behavior before changing lifecycle implementation.

Acceptance criteria:

- Tests cover normal completion, cancellation, shutdown, killed process, and crash paths.
- Tests assert current terminal event mapping.
- Tests prove count/event cleanup reaches steady state after each path.
- No production behavior changes.

Reason mapping to preserve:

```elixir
:normal -> no event
:cancelled -> {:cancelled, nil}
:shutdown -> {:terminated, nil}
:killed -> {:terminated, :killed}
{:shutdown, reason} -> {:terminated, reason}
other -> {:crashed, %{message: Exception.format_exit(other)}}
```

Likely files:

- `apps/swarm_ai/test/swarm_ai/supervisor_test.exs`
- Existing execution/runtime tests if present

Value:

- Makes the watcher rewrite safe and reviewable.

Scope:

- Less than 150 LOC.

Deployable:

- Yes. Test-only.

Verification:

- Added terminal semantics coverage in `apps/swarm_ai/test/swarm_ai/supervisor_test.exs`.
- Covered normal completion, cancellation, shutdown, killed process, shutdown tuple, crash, and steady-state cleanup.
- `HEX_HOME="/tmp/opencode/hex" mix test` in `apps/swarm_ai`: 116 passed.
- Note: local `~/.hex/hex.config` is malformed; temp `HEX_HOME` was used for verification without modifying user config.

## Deliverable 2: Replace Raw Death Watcher With OTP Monitor

Status: Complete.

Description: Remove raw `spawn_death_watcher/1`. Runtime process monitors execution workers and maps `:DOWN` reasons to the same terminal events covered by Deliverable 1.

Acceptance criteria:

- No raw `spawn/1` watcher remains for execution lifecycle.
- Terminal event semantics match the tests from Deliverable 1.
- Runtime monitor is part of the supervised runtime ownership model.
- No monitor process can outlive application dependencies during shutdown.
- No process that writes terminal task state outlives `FrontmanServer.Repo`.

Likely files:

- `apps/swarm_ai/lib/swarm_ai/execution_worker.ex`
- `apps/swarm_ai/lib/swarm_ai/supervisor.ex` or runtime module
- `apps/swarm_ai/test/swarm_ai/supervisor_test.exs`

Value:

- Fixes the OTP violation behind unmanaged shutdown crashes.
- Deletes watcher code, likely net-negative.

Scope:

- Less than 350 LOC changed.
- Net-negative expected inside `execution_worker.ex`.

Deployable:

- Yes. Behavior parity required.

Implementation notes:

- Removed raw `spawn_death_watcher/1` and `watcher_loop/3` from `apps/swarm_ai/lib/swarm_ai/execution_worker.ex`.
- Added supervised `SwarmAi.Runtime` GenServer to start execution workers and monitor worker `:DOWN` events.
- Added `SwarmAi.TerminalEvent.emit/2` for shared exit-reason-to-terminal-event mapping.
- `SwarmAi.run/2` resolves the runtime process name and calls the supervised runtime process directly.
- `ExecutionWorker.terminate/2` handles supervisor shutdown paths because OTP calls it before the worker dies; this preserves registry/task-supervisor crash semantics without an unmanaged watcher.
- `SwarmAi.execution_finished/2` removes completed executions from runtime monitor state after the worker has already emitted final status. This prevents later dependency teardown from producing duplicate or fake terminal events.
- Deleted the nested `RuntimeSupervisor` experiment; `SwarmAi.Supervisor` remains a single supervision tree with `Runtime`, `Registry`, `Task.Supervisor`, and `DynamicSupervisor`.

Simplifications applied during review:

- Moved runtime-process namespace resolution into `SwarmAi.run/2` instead of `SwarmAi.Runtime.run/2`.
- Renamed runtime process helper to `runtime_process_name/1` for clarity.
- Removed dependency monitors for Registry and ExecutionSupervisor; worker shutdown callback plus worker monitor cover required semantics.
- Extracted terminal event mapping out of `SwarmAi.Runtime` so Runtime only owns lifecycle monitoring.
- Tried removing normal-path `execution_finished/2`; tests proved it caused fake crash events after normal completion under suite load, so it remains.

Verification:

- `HEX_HOME="/tmp/opencode/hex" mix compile --warnings-as-errors --all-warnings` in `apps/swarm_ai`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix test` in `apps/swarm_ai`: 116 passed.
- Grep confirms no `spawn_death_watcher`, `watcher_loop`, or lifecycle raw `spawn(` remains in `apps/swarm_ai/lib`.

## Deliverable 3: Add SwarmAi Active Execution Count

Status: Complete as part of Deliverable 10.

Description: Runtime exposes active execution count from supervised execution ownership. No drain or reject behavior.

API:

```elixir
SwarmAi.active_count(FrontmanServer.AgentRuntime)
```

Acceptance criteria:

- Count increments when execution worker starts.
- Count decrements when worker exits.
- Count reaches zero after normal completion, cancel, crash, and supervisor shutdown.
- Count is maintained by the runtime process that owns/monitors executions.
- Tests cover count lifecycle.

Likely files:

- `apps/swarm_ai/lib/swarm_ai.ex`
- `apps/swarm_ai/lib/swarm_ai/supervisor.ex` or runtime module
- `apps/swarm_ai/test/swarm_ai/supervisor_test.exs`

Value:

- Old slot can report whether agent work is still running.
- Deploy polling consumes runtime-owned truth instead of ad hoc process state.

Scope:

- Less than 200 LOC.

Deployable:

- Yes. Observability only.

Implementation note:

- Added with deploy polling as the first production caller.
- `SwarmAi.active_count/1` delegates to `SwarmAi.Runtime.active_count/1`.
- Count is derived from the runtime monitor map that owns execution lifecycle state.

Verification:

- Added active-count lifecycle coverage in `apps/swarm_ai/test/swarm_ai/supervisor_test.exs`.
- Covered running count and return-to-zero after shutdown and crash.
- `HEX_HOME="/tmp/opencode/hex" mix test test/swarm_ai/supervisor_test.exs` in `apps/swarm_ai`: 15 passed.

## Deliverable 4: Split Health And Readiness

Status: Complete.

Description: Add `/ready` separate from existing `/health`. `/health` means node alive. `/ready` means eligible for new traffic.

Acceptance criteria:

- `/health` unchanged.
- `/ready` returns 200 when app can receive traffic.
- `/ready` has no DB dependency.
- Controller tests cover `/health` and `/ready`.

Likely files:

- `apps/frontman_server/lib/frontman_server_web/controllers/health_controller.ex`
- `apps/frontman_server/lib/frontman_server_web/router.ex`
- `apps/frontman_server/test/frontman_server_web/controllers/health_controller_test.exs`

Value:

- Deploy/proxy can distinguish alive from routable.

Scope:

- Less than 100 LOC.

Deployable:

- Yes. No behavior changes until deploy scripts use `/ready`.

Implementation notes:

- Added root `GET /ready` in the `:api` pipeline for deploy/proxy readiness checks without browser session, auth, or CSRF.
- Kept existing `GET /health/ready` as a compatibility alias.
- Changed readiness response to `{"status":"ready"}` and removed the `Repo`/SQL dependency from `HealthController.ready/2`.
- `/health` remains unchanged and returns `{"status":"ok"}`.

Verification:

- Added controller tests in `apps/frontman_server/test/frontman_server_web/controllers/health_controller_test.exs` for `/health`, `/ready`, and `/health/ready`.
- `mix format --check-formatted` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix compile --warnings-as-errors --all-warnings` in `apps/frontman_server`: clean.
- Initial controller test execution was blocked by unavailable local Postgres while `frontman_server` booted Oban.
- After local app boot was available, `HEX_HOME="/tmp/opencode/hex" mix test test/frontman_server/drain_test.exs test/frontman_server_web/controllers/health_controller_test.exs` in `apps/frontman_server`: 7 passed.

## Deliverable 5: Add Drain State

Status: Complete under no-unused-production-API policy.

Description: Add tiny supervised `FrontmanServer.Drain` process. It tracks whether current node is draining for routing eligibility only.

API:

```elixir
FrontmanServer.Drain.start_draining()
FrontmanServer.Drain.ready?()
```

Acceptance criteria:

- Drain state defaults to not draining on boot.
- `/ready` returns 503 while draining.
- Existing requests continue working while draining.
- No task or agent logic rejects work because of drain state.
- Tests cover state transitions.

Likely files:

- `apps/frontman_server/lib/frontman_server/drain.ex`
- `apps/frontman_server/lib/frontman_server/application.ex`
- Health controller tests

Value:

- Old slot can be removed from traffic without being killed.

Scope:

- Less than 150 LOC.

Deployable:

- Yes. Safe standalone.

Implementation notes:

- Added supervised `FrontmanServer.Drain` process with boot state not draining.
- Added `FrontmanServer.Drain.ready?/0`; first production caller is `HealthController.ready/2`.
- Added `FrontmanServer.Drain.start_draining/0`; first production callers are deploy script release RPC commands in Deliverable 7.
- `/ready` and `/health/ready` now derive readiness from `FrontmanServer.Drain.ready?/0`.
- Exported `FrontmanServer.Drain` through the `FrontmanServer` boundary for web-layer use.
- Did not add `stop_draining/0` or `draining?/0` because they have no in-code production caller.
- `/ready` returns 503 while draining after `start_draining/0`.

Verification:

- Added `apps/frontman_server/test/frontman_server/drain_test.exs` coverage for boot readiness.
- Extended `apps/frontman_server/test/frontman_server_web/controllers/health_controller_test.exs` to cover `/ready` through drain readiness.
- `mix format --check-formatted` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix compile --warnings-as-errors --all-warnings` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix test test/frontman_server/drain_test.exs test/frontman_server_web/controllers/health_controller_test.exs` in `apps/frontman_server`: 7 passed.

## Deliverable 6: Add Frontman Drain Status RPC

Status: Complete as part of Deliverable 10.

Description: Add one function returning routing drain state and runtime-owned active execution count for deploy polling.

API:

```elixir
FrontmanServer.Drain.status()
# %{draining: true, active_executions: 2}
```

Acceptance criteria:

- Status includes `draining`.
- Status includes `SwarmAi.active_count(FrontmanServer.AgentRuntime)`.
- Output is RPC-friendly.
- No DB dependency.
- Tests cover status shape.

Likely files:

- `apps/frontman_server/lib/frontman_server/drain.ex`
- `apps/frontman_server/test/frontman_server/drain_test.exs`

Value:

- Deploy script can poll active work without parsing logs or hitting private endpoints.

Scope:

- Less than 80 LOC.

Deployable:

- Yes.

Implementation note:

- Added with deploy polling as the first production caller.
- `FrontmanServer.Drain.status/0` returns `%{draining: boolean(), active_executions: non_neg_integer()}`.
- Status has no DB dependency and reads active execution count from `SwarmAi.active_count(FrontmanServer.AgentRuntime)`.

Verification:

- Added status shape coverage in `apps/frontman_server/test/frontman_server/drain_test.exs`.
- `HEX_HOME="/tmp/opencode/hex" mix test test/frontman_server/drain_test.exs` in `apps/frontman_server`: 3 passed.

## Deliverable 7: Add Release RPC Drain Command

Status: Complete.

Description: Use release RPC to mark active slot draining from deploy script.

Command shape:

```bash
/opt/frontman/blue/current/bin/frontman_server rpc "FrontmanServer.Drain.start_draining()"
```

Acceptance criteria:

- RPC flips `/ready` to 503 on target slot.
- Command works per blue/green slot using existing release node config.
- No public admin endpoint added.

Likely files:

- `infra/production/deploy.sh`
- `infra/production/build-and-deploy.sh`
- Possibly `infra/production/env.template`

Value:

- Deployment can control readiness safely without exposing a network mutator endpoint.

Scope:

- Less than 50 LOC.

Deployable:

- Yes. No app behavior change beyond callable drain state.

Implementation notes:

- Added `FrontmanServer.Drain.start_draining/0`; first production callers are deploy script release RPC commands.
- `deploy.sh` and `build-and-deploy.sh` call `FrontmanServer.Drain.start_draining()` on the active slot after inactive slot readiness succeeds and before Caddy switches traffic.
- `/ready` now returns 503 with `{"status":"draining"}` after `start_draining/0`.
- Did not add `stop_draining/0`; inactive slot restart defaults drain state to ready, and no production caller needs stop-drain yet.
- Active-slot drain RPC is wrapped by `start_active_draining`, which sources the active slot env in a subshell and tolerates old active releases that do not yet define `FrontmanServer.Drain`.

Verification:

- Added drain mutation and `/ready` 503 tests.
- `mix format --check-formatted` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix compile --warnings-as-errors --all-warnings` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix test test/frontman_server/drain_test.exs test/frontman_server_web/controllers/health_controller_test.exs` in `apps/frontman_server`: 7 passed.
- `bash -n infra/production/deploy.sh`: clean.
- `bash -n infra/production/build-and-deploy.sh`: clean.

## Deliverable 8: Switch Deploy Health Check To Readiness

Status: Complete.

Description: New slot must pass `/ready`, not only `/health`, before traffic switch.

Acceptance criteria:

- Deploy waits for inactive slot `/ready`.
- Failed inactive slot keeps active slot unchanged.
- Active slot is not marked draining until inactive slot is ready.
- Rollback path still uses correct liveness/readiness semantics.

Likely files:

- `infra/production/deploy.sh`
- `infra/production/build-and-deploy.sh`
- `infra/production/rollback.sh`

Value:

- Prevents routing traffic to a booted-but-not-ready release.

Scope:

- Less than 80 LOC.

Deployable:

- Yes.

Implementation notes:

- `deploy.sh`, `build-and-deploy.sh`, and `rollback.sh` now wait on `/ready` instead of `/health`.
- Readiness variable/log names replaced health naming (`READY_PATH`, `READY_TIMEOUT`, `READY_INTERVAL`, `READY`).
- Active slot drain RPC still runs only after inactive slot readiness succeeds.
- Failed inactive slot still stops inactive slot and leaves active slot unchanged.

Verification:

- `bash -n infra/production/deploy.sh`: clean.
- `bash -n infra/production/build-and-deploy.sh`: clean.
- `bash -n infra/production/rollback.sh`: clean.
- Grep confirms no `HEALTH_PATH`, `HEALTHY`, `HEALTH_TIMEOUT`, `HEALTH_INTERVAL`, `/health`, `healthy`, or `health check` remains in production shell scripts.

## Deliverable 9: Consolidate Deploy Logic

Status: Complete.

Description: Remove duplicated blue/green logic between `deploy.sh` and `build-and-deploy.sh`. Either make `build-and-deploy.sh` build then call `deploy.sh`, or extract shared helper.

Acceptance criteria:

- One canonical implementation for health/readiness loop, Caddy rewrite, active slot marker update, drain polling, and old slot stop.
- Duplicate shell blocks removed.
- Existing deploy entrypoint still works.
- Behavior equivalent plus readiness/drain improvements.

Likely files:

- `infra/production/deploy.sh`
- `infra/production/build-and-deploy.sh`
- Optional `infra/production/lib/deploy-common.sh`

Value:

- Reduces chance drain logic diverges.
- Main source of net-negative LOC.

Scope:

- Less than 300 LOC changed.
- Net-negative expected.

Deployable:

- Yes. Shell-only deploy improvement.

Implementation notes:

- `deploy.sh` is now the canonical blue/green deploy implementation for readiness loop, drain RPC, Caddy rewrite, active slot marker update, old slot stop, release cleanup, and tarball cleanup.
- `build-and-deploy.sh` now builds the release and then calls sibling `deploy.sh` with the built tarball.
- Removed duplicated blue/green slot selection, readiness polling, Caddy rewrite, drain RPC, active marker, old slot stop, and release cleanup from `build-and-deploy.sh`.

Verification:

- `bash -n infra/production/build-and-deploy.sh`: clean.
- `bash -n infra/production/deploy.sh`: clean.
- `test -x infra/production/deploy.sh && test -x infra/production/build-and-deploy.sh && test -x infra/production/rollback.sh`: clean.
- Manual inspection confirms `build-and-deploy.sh` now has only build phase plus `deploy.sh` handoff.

## Deliverable 10: Replace Fixed Sleep With Execution Drain Wait

Status: Complete.

Description: After Caddy switch, deploy script polls old slot until active execution count is zero or timeout expires.

Acceptance criteria:

- No hardcoded `sleep 5` pretending to drain.
- Poll interval and timeout are configurable.
- Logs show active execution count.
- Timeout proceeds to stop old slot.
- New traffic already routes to new slot before wait starts.
- Deploy script treats runtime status as source of truth; it does not infer execution state from processes or logs.

Likely files:

- `infra/production/deploy.sh`
- Shared deploy helper if added
- `infra/production/env.template`

Value:

- Existing agent runs can finish on old slot during deploy.

Scope:

- Less than 120 LOC.

Deployable:

- Yes after Deliverables 3 and 6.

Implementation notes:

- Removed fixed `sleep 5` from canonical `infra/production/deploy.sh`.
- Added configurable `DRAIN_TIMEOUT` and `DRAIN_INTERVAL` environment overrides, defaulting to 300s and 5s.
- After Caddy reload routes new traffic to the inactive slot, deploy polls old active slot release RPC for `FrontmanServer.Drain.status().active_executions`.
- Deploy logs active execution count each poll.
- Deploy stops old slot after count reaches zero or after drain timeout, logging remaining count on timeout.
- `active_execution_count` sources the active slot env via `slot_rpc` before calling release RPC, so blue/green node/cookie values are correct.
- If the old active release cannot answer drain status during the first rollout, `active_execution_count` logs a warning to stderr and returns `0` so deploy continues instead of aborting after starting the inactive slot.
- Migrations now run in an inactive-slot env subshell so inactive release env does not leak into later active-slot RPCs.

Verification:

- `HEX_HOME="/tmp/opencode/hex" mix format --check-formatted` in `apps/swarm_ai`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix compile --warnings-as-errors --all-warnings` in `apps/swarm_ai`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix test test/swarm_ai/supervisor_test.exs` in `apps/swarm_ai`: 15 passed.
- `HEX_HOME="/tmp/opencode/hex" mix format --check-formatted` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix compile --warnings-as-errors --all-warnings` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix test test/frontman_server/drain_test.exs` in `apps/frontman_server`: 3 passed.
- `bash -n infra/production/deploy.sh`: clean.
- Grep confirms no hardcoded `sleep 5` remains in production deploy script.
- `yarn changeset status --since=origin/main`: clean after empty changeset frontmatter fix.
- Codex review P1s for active-slot env sourcing and old-release RPC compatibility were addressed in commit `b42a90ee`.

## Deliverable 11: Configure HTTP Server Shutdown Timeout

Status: Complete.

Description: Make Bandit/Thousand Island shutdown timeout explicit and align systemd timeout.

Acceptance criteria:

- Endpoint config has explicit `thousand_island_options: [shutdown_timeout: ...]`.
- systemd `TimeoutStopSec` exceeds app drain timeout.
- Values are documented in env/template or deploy comments.
- No timeout conflict where systemd kills BEAM before app drain can finish.

Likely files:

- `apps/frontman_server/config/runtime.exs`
- `infra/production/systemd/frontman-blue.service`
- `infra/production/systemd/frontman-green.service`
- `infra/production/env.template`

Value:

- Long HTTP/WebSocket shutdown behavior becomes intentional.

Scope:

- Less than 80 LOC.

Deployable:

- Yes.

Implementation notes:

- Added production `HTTP_SHUTDOWN_TIMEOUT_MS`, defaulting to `30000`.
- Wired `HTTP_SHUTDOWN_TIMEOUT_MS` into Bandit/Thousand Island via `thousand_island_options: [shutdown_timeout: http_shutdown_timeout_ms]`.
- Raised blue/green systemd `TimeoutStopSec` from 30s to 45s so systemd does not kill BEAM before HTTP shutdown drain can finish.
- Documented timeout relationship in `infra/production/env.template` and both systemd unit files.
- Did not add explicit Phoenix socket `drainer:` options; Phoenix socket draining exists by default, and this deliverable targets HTTP server shutdown timing.

Verification:

- `HEX_HOME="/tmp/opencode/hex" mix format --check-formatted` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix compile --warnings-as-errors --all-warnings` in `apps/frontman_server`: clean.
- `MIX_ENV=prod ... mix run --no-start -e '...'` in `apps/frontman_server` confirmed runtime endpoint config contains `thousand_island_options: [shutdown_timeout: 30000]`.
- Grep confirms both blue and green systemd units set `TimeoutStopSec=45`.

## Deliverable 12: Make Controlled Deploy Termination Non-Noisy If Still Needed

Status: Skipped. Existing behavior already satisfies this after Deliverables 2, 10, and 11.

Description: After OTP monitor and supervision ordering are fixed, handle remaining expected deploy termination cases intentionally. This is not a substitute for correct process ownership.

Acceptance criteria:

- Supervision tests prove no process that needs `Repo` outlives `Repo`.
- Expected deploy termination logs at info/warn, not error.
- Real execution crash still records agent error and Sentry signal.
- No silent swallow of unexpected exceptions during normal runtime.
- If no noise remains after Deliverables 1-3 and 11, this deliverable is skipped.

Likely files:

- `apps/frontman_server/lib/frontman_server/tasks.ex`
- Task tests

Value:

- Deploy shutdown no longer pollutes Sentry or task history.
- Keeps exception handling narrow and evidence-driven.

Scope:

- Less than 120 LOC if needed.

Deployable:

- Yes after OTP monitor change.

Skip evidence:

- `SwarmAi.TerminalEvent.emit/2` maps `:shutdown`, `:killed`, and `{:shutdown, reason}` to `{:terminated, _}` events and logs at info.
- `FrontmanServer.Tasks.persist_swarm_event/4` handles `{:terminated, _}` with `Logger.info/1` and persists `:terminated`; it does not call `Sentry.capture_message/2`.
- Real crashes still route through `{:crashed, %{message: message}}`, which `FrontmanServer.Tasks` captures in Sentry and persists as an agent error.
- No remaining evidence shows expected deploy termination emitting `Logger.error/2` or Sentry errors.

Verification:

- Manual code inspection of `apps/swarm_ai/lib/swarm_ai/terminal_event.ex`, `apps/swarm_ai/lib/swarm_ai/execution_worker.ex`, and `apps/frontman_server/lib/frontman_server/tasks.ex`.

## Deliverable 13: Drain Observability

Status: Complete.

Description: Add concise logs around drain lifecycle.

Acceptance criteria:

- Log when slot enters drain.
- Log active execution count during deploy wait.
- Log drain complete with duration.
- Log drain timeout with count remaining.
- No expected deploy path emits Sentry error.

Likely files:

- `FrontmanServer.Drain`
- Deploy script/helper

Value:

- Next deploy incident has evidence.

Scope:

- Less than 80 LOC.

Deployable:

- Yes.

Implementation notes:

- Added `Logger.info/1` when `FrontmanServer.Drain.start_draining/0` first moves a node into drain state.
- Drain-entry log includes active execution count at drain start.
- Kept repeated `start_draining/0` idempotent and quiet to avoid duplicate logs.
- Existing deploy polling already logs active execution count each poll, drain completion duration, and timeout with remaining active count.
- No expected deploy path emits `Logger.error/2`; Sentry logger captures only error-level logs.

Verification:

- Added log coverage in `apps/frontman_server/test/frontman_server/drain_test.exs`.
- `HEX_HOME="/tmp/opencode/hex" mix test test/frontman_server/drain_test.exs` in `apps/frontman_server`: 4 passed.
- `HEX_HOME="/tmp/opencode/hex" mix format --check-formatted` in `apps/frontman_server`: clean.
- `HEX_HOME="/tmp/opencode/hex" mix compile --warnings-as-errors --all-warnings` in `apps/frontman_server`: clean.
- `bash -n infra/production/deploy.sh`: clean.

## Deliverable 14: Optional Long-Lived Connection Count

Status: Deferred. No evidence currently justifies adding connection tracking.

Description: Add connection/session count only if needed after execution drain. Prefer not doing this unless evidence shows WebSocket/LiveView cuts still matter.

Acceptance criteria:

- Counts only long-lived sockets/channels, not every HTTP request.
- Count increments/decrements reliably.
- Drain status can include it.
- Deploy can wait on it if enabled.

Likely files:

- Socket/channel modules
- `FrontmanServer.Drain`
- Tests if practical

Value:

- More complete drain for streaming clients.

Scope:

- Less than 200 LOC.

Deployable:

- Yes.

Recommendation:

- Defer. Net-negative goal favors not adding unless incident data proves need.

Deferral evidence:

- Current deploy flow drains supervised agent execution work, which is the stated primary risk.
- Phoenix provides socket draining by default during application shutdown, and Deliverable 11 made HTTP shutdown timing explicit.
- No deploy logs or production evidence in this work show WebSocket/LiveView cuts remain a problem after execution drain.
- Adding socket/channel counters would increase runtime state and API surface without a production-proven caller need.
- Revisit only if deploy observations show long-lived socket cuts affect users after Deliverables 10, 11, and 13 are deployed.

## Implementation Order

1. Deliverable 1: lock current execution terminal semantics.
2. Deliverable 2: replace raw death watcher with OTP monitor.
3. Deliverable 3: SwarmAi active execution count.
4. Deliverable 4: `/ready`.
5. Deliverable 5: drain state.
6. Deliverable 6: drain status RPC.
7. Deliverable 7: release RPC drain command.
8. Deliverable 8: deploy waits on `/ready`.
9. Deliverable 9: consolidate deploy scripts.
10. Deliverable 10: replace `sleep 5` with execution drain wait.
11. Deliverable 11: timeout alignment.
12. Deliverable 12 only if controlled deploy termination is still noisy.
13. Deliverable 13: observability.
14. Deliverable 14 only if data requires connection-level drain.

## Checkpoints

After Deliverables 1-3:

- No raw lifecycle watcher.
- Runtime owns execution monitoring.
- Active execution count comes from supervised runtime state.
- Repo shutdown order protected by supervision.

After Deliverables 4-8:

- Blue/green routing uses readiness.
- Old slot can be marked draining.
- New traffic never lands on draining old slot.

After Deliverables 9-11:

- Deploy script duplication reduced.
- Old slot waits for active agent executions.
- No fixed drain sleep.
- Shutdown timeouts aligned.

After Deliverables 12-13:

- Sentry error class should be gone.
- Expected deploy paths are logged clearly.
- Any remaining termination handling is narrow and evidence-backed.

## Line Budget

Expected additions:

- Lifecycle parity tests: 80-150 LOC.
- OTP monitor rewrite and active count: 120-250 LOC.
- `Drain` module/tests/status: 150-220 LOC.
- Deploy drain polling: 80-140 LOC.
- Timeout/readiness wiring: 80 LOC.

Expected deletions:

- Raw death watcher code: 60-90 LOC.
- Duplicated deploy script blocks: likely 150-300 LOC.
- Fake `sleep 5` logic and duplicate Caddy/health snippets: 50-150 LOC.

Net-negative path:

- Must do Deliverable 2.
- Must do Deliverable 9.
- Avoid optional connection tracking unless required.
- Keep drain API tiny.
- No admin endpoints or UI.
- Do not add Repo-unavailable defensive code unless evidence remains after supervision fix.

## Primary Risk

SwarmAi monitor rewrite can change terminal event behavior.

Mitigation:

- First write tests matching current death watcher reason mapping.
- Swap implementation only after parity tests exist.
- Keep worker normal completion path unchanged.
- Keep terminal event persistence inside processes whose lifetime is ordered before `Repo` shutdown.

## Correct Rule

New agent runs are never rejected due to drain. They land on the new slot because Caddy routes new traffic there. Old slot drains existing work only.
