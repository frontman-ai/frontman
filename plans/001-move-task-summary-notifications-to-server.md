# Plan 001: Send task summaries when a server turn completes

> **Executor instructions**: Follow this plan step by step. Run every verification command and
> confirm the expected result before moving on. If a STOP condition occurs, stop and report; do not
> improvise. When done, update this plan's row in `plans/README.md` unless a reviewer says they own
> the index.
>
> **Drift check (run first)**:
> `git diff --stat ffee6ed3..HEAD -- apps/frontman_server apps/frontman_notifier infra/production .github/workflows/deploy.yml .github/workflows/deploy-notifier.yml CHANGELOG.md`
> If an in-scope file changed, compare the current code with the excerpts below. A material mismatch
> is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: none
- **Category**: migration
- **Planned at**: commit `ffee6ed3`, 2026-09-04

## Goal

When Frontman Server durably records a successful `agent_completed` interaction, it atomically
queues one Discord summary for that task and turn. Frontman Notifier keeps only stargazer alerts.
The destination remains the existing `DISCORD_TASK_SUMMARIES_WEBHOOK_URL`, so summaries and agent
feedback continue to reach the same Discord channel/thread.

## Why this matters

The old notifier infers completion by polling for 30 minutes of inactivity. Frontman Server does not
need that heuristic: it owns the execution lifecycle and persists the exact successful terminal
interaction. Triggering from that durable write removes hourly scheduling, idle/lookback tuning,
direct notifier database access, and DETS task-summary state. Deployment still needs a staged
handoff because the old poller and new event producer must never be active together.

## Deeper findings

### The canonical completion point is task persistence, not the channel

`apps/frontman_server/lib/frontman_server/tasks.ex:332-334` maps Swarm's successful terminal event to
the task outcome path:

```elixir
defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, :completed) do
  persist_execution_outcome(scope, task_id, turn_number, :completed)
end
```

`record_execution_outcome/4` maps `:completed` to an `agent_completed` interaction:

```elixir
:completed ->
  {:agent_completed, %{result: nil}}
```

All production completion paths converge on this code, including execution-start failures and
Swarm events for completed, failed, crashed, cancelled, terminated, and paused outcomes. The
successful "done" signal is specifically `:agent_completed`.

`record_interaction_row/2` already performs the durable interaction insert and task timestamp update
inside one `Repo.transact/1`, then broadcasts only after commit:

```elixir
Repo.transact(fn ->
  with {:ok, schema} <- ... |> Repo.insert(),
       {1, _} <- ... |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)]) do
    {:ok, schema}
  end
end)
```

This transaction is the correct enqueue boundary. Insert the Oban job in this same transaction after
the interaction and task update. If the transaction commits, both completion and notification job
exist. If it rolls back, neither exists.

Do **not** enqueue from `FrontmanServerWeb.TaskChannel.finalize_turn/3`. That function translates
persisted outcomes into ACP UI state, clears socket state, and starts queued work. It is only a
PubSub consumer. `Interaction.AgentError` explicitly documents that terminal persistence must
survive a dead channel, so a channel hook would miss summaries after disconnects.

### One task can have multiple completed turns

`Tasks.History` treats `agent_completed`, `agent_error`, and `agent_paused` as terminal interaction
types, and `AgentRetry` can reopen a turn. Tests also prove one task can persist multiple
`AgentCompleted` interactions across multiple turns. Therefore the event identity is
`{task_id, turn_number}`, not only `task_id`.

This plan sends one summary for every successfully completed turn. It does not send "done" for:

- retryable or exhausted errors (`agent_error`),
- cancellation or supervisor termination (also represented as `agent_error`),
- tool-timeout pauses (`agent_paused`).

That is intentional: those outcomes are resolved/terminal in history, but they are not successful
"task done" events. Errors from earlier attempts remain visible in a later successful turn's summary.
If product requirements still require standalone red summaries for tasks that never complete, stop:
that is a separate outcome-notification policy and cannot be inferred from "report the task as done."

### The queued job must summarize a stable turn snapshot

The notification queue may run after a later user message or turn has started. The worker must not
blindly summarize every current interaction. Load the task through the authorized `Tasks` context,
project interaction ownership with `Tasks.History`, and include only rows attributed through the job's
`turn_number`. Exclude unclaimed user messages and interactions from later turns. This keeps each
Discord message tied to the completion that caused it.

### Oban is transport, not a scheduler

Frontman Server already has Oban and a `notifications` queue. Use a normal job inserted by the
completion transaction. Do not add `Oban.Plugins.Cron`, a timer, a periodic reconciliation job, a
lookback query, or a delay. Oban provides durable execution and retries only.

### No delivery-state migration is required

Only new `agent_completed` writes enqueue jobs. Historical completions do not replay, so no task
column, notification table, DETS import, or baseline migration is needed. Oban uniqueness on
`task_id` plus `turn_number` prevents duplicate jobs for the same completion while the job exists.
The old DETS file remains untouched for rollback but is no longer read after cutover.

## Required design

### Server worker

Create `FrontmanServer.Workers.SendTaskSummaryToDiscord`:

- `use Oban.Worker` on `queue: :notifications`, `max_attempts: 3`;
- unique by `[:task_id, :turn_number]`, with `period: :infinity` and the same explicit state list used
  by `FrontmanServer.Workers.GenerateTitle`;
- args: `user_id`, `task_id`, and positive `turn_number`;
- reconstruct `%Accounts.Scope{}` from `user_id`, then load the task through `Tasks.get_task/2`;
- return `:discard` if the user or task no longer exists;
- build the summary from rows attributed through the requested turn only;
- verify that the requested turn contains `agent_completed`; return `:discard` for malformed/stale
  jobs rather than posting a false completion;
- POST the existing embed shape with `receive_timeout: 15_000` and `retry: false`; Oban owns retries;
- accept HTTP 2xx as success, matching existing server Discord workers;
- read the same `webhook_url` already provided to agent feedback;
- check `enabled` in `perform/1` as an operational kill switch.

There is no post-success task marker. Job identity is the completion event itself.

### Atomic event enqueue

In `Tasks.record_interaction_row/2`, after inserting and updating the task but before the transaction
returns, call a small private helper:

- `%InteractionSchema{type: :agent_completed, turn_number: turn_number}` with notifications enabled:
  build and `Oban.insert/1` `SendTaskSummaryToDiscord` using the task's `user_id`, task ID, and turn;
- all other interaction types, or disabled notifications: return `:ok` without a job;
- an Oban insert error must return `{:error, reason}` from the transaction so completion and job do
  not diverge.

Keep the existing post-commit PubSub broadcast behavior unchanged.

### Summary parity

Port the current embed fields, colors, limits, and truncation behavior from
`FrontmanNotifier.TaskSummaries`:

- title and user-attempt description;
- user, framework, task ID, stats, issues, issue details, tools, and timing fields;
- green when the included snapshot has no agent errors, tool errors, or pauses; red otherwise;
- at most three user messages and eight issue details;
- Discord-safe title/description/field truncation.

Replace raw SQL maps with typed `TaskSchema`, `InteractionSchema`, and `Interaction` structs. Reuse
`Interaction.user_prompt_text/1` or the persisted `UserMessage.messages` rather than decoding JSON.
Do not port the candidate query, idle threshold, lookback, maximum-per-run setting, standalone
Postgrex wrapper, or DETS checks.

### Configuration and channel preservation

Add worker config with `enabled: false`, `webhook_url: nil`, and test-only `req_options` defaults.
In production, parse `FRONTMAN_TASK_SUMMARY_NOTIFICATIONS_ENABLED` as a strict boolean, defaulting to
`false` for the staged cutover. Configure the worker with that flag and the exact existing local:

```elixir
discord_task_summaries_webhook_url =
  env!("DISCORD_TASK_SUMMARIES_WEBHOOK_URL", :string!)
```

Do not rename or duplicate the webhook variable. Keep
`apps/frontman_server/rel/env.sh.eex`, `/opt/frontman/shared/discord.env`, and the agent-feedback
configuration unchanged.

## Repository conventions

- Follow `agent_docs/elixir-style.md`: explicit control flow, guards at boundaries, bounded lists,
  request timeouts, tagged operational errors, and compiler warnings as errors.
- Public context functions touching user data take `%Scope{}`. The worker must reconstruct a scope as
  `GenerateTitle` does; it must not query another user's task by raw ID.
- Keep query construction in schema modules. Prefer the already-loaded rows from `Tasks.get_task/2`;
  do not add raw SQL.
- Model worker HTTP tests after
  `test/frontman_server/workers/send_agent_feedback_to_discord_test.exs` and atomic Oban assertions
  after the existing `Oban.Testing` patterns.
- Use Makefiles. In a containerized worktree, prefix toolchain commands with `./bin/pod-exec`.
- Do not modify the existing uncommitted `mise.toml` change.

## Commands

| Purpose | Command | Expected on success |
|---|---|---|
| Server tests | `make -C apps/frontman_server test` | exit 0; all server tests pass |
| Server checks | `make -C apps/frontman_server check` | exit 0; formatter, Credo, and tests pass |
| Server production compile | `make -C apps/frontman_server build` | exit 0 with warnings as errors |
| Notifier checks | `make -C apps/frontman_notifier precommit` | exit 0 |
| Shared-env test | `bash infra/production/ensure-shared-discord-env.test.sh` | exit 0 |
| Scope review | `git status --short` | only in-scope files, plan files, and pre-existing `mise.toml` appear |

## Scope

**In scope:**

- `apps/frontman_server/lib/frontman_server/workers/send_task_summary_to_discord.ex` (create)
- `apps/frontman_server/test/frontman_server/workers/send_task_summary_to_discord_test.exs` (create)
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`
- `apps/frontman_server/lib/frontman_server.ex`
- `apps/frontman_server/config/config.exs`
- `apps/frontman_server/config/runtime.exs`
- `apps/frontman_server/config/test.exs`
- `apps/frontman_notifier/lib/frontman_notifier.ex`
- `apps/frontman_notifier/lib/frontman_notifier/scheduler.ex` (documentation only if needed)
- `apps/frontman_notifier/lib/frontman_notifier/config.ex`
- `apps/frontman_notifier/lib/frontman_notifier/database.ex` (delete)
- `apps/frontman_notifier/lib/frontman_notifier/task_summaries.ex` (delete)
- `apps/frontman_notifier/test/frontman_notifier/task_summaries_test.exs` (delete)
- `apps/frontman_notifier/mix.exs`
- `apps/frontman_notifier/mix.lock`
- `apps/frontman_notifier/README.md`
- `apps/frontman_notifier/rel/env.sh.eex` (delete)
- `infra/production/notifier/env.template`
- `infra/production/notifier/setup.sh`
- `infra/production/notifier/build-and-deploy.sh`
- `infra/production/notifier/systemd/frontman-notifier.service`
- `infra/production/ensure-shared-discord-env.test.sh`
- `infra/production/server-setup.sh`
- `CHANGELOG.md`
- `plans/README.md`

**Out of scope:**

- Any cron plugin, timer, delayed job, polling query, lookback, idle threshold, or per-run limit.
- Database migrations or new task/notification columns.
- Failed, cancelled, terminated, paused, or merely idle task notifications.
- Stargazer behavior or its DETS state.
- Changing either Discord webhook value or destination.
- Refactoring existing server Discord workers into a shared client.
- Deleting the notifier application or service; it still owns stargazer alerts.
- Deleting `/opt/frontman-notifier/state` during the rollback window.
- `mise.toml`.

## Git workflow

- Deliver this as two ordered PRs, not one combined PR:
  1. `feature/event-driven-task-summaries-server` contains only the server worker, event enqueue,
     server tests/config/deployment template, and changelog.
  2. `feature/remove-polled-task-summaries` branches from PR 1 after it lands and contains only the
     notifier cleanup and shared-env test narrowing.
- Create each with `make worktree-create BRANCH=<branch>` as required by `AGENTS.md`.
- PR 1 must deploy with the production feature flag false before PR 2 is merged.
- After PR 2 deploys, enabling the live flag and manually dispatching the server workflow is Stage C;
  it does not require a third code change.
- Do not push, merge, or deploy either PR until an operator approves the staged runbook in Step 6.

## Steps

### Step 1: Add the event-driven server worker

Create `SendTaskSummaryToDiscord` with the required Oban options and configuration. Add a pure public
`build_summary_embed/3` taking the task, user, and bounded interaction rows so format parity is easy
to test. Keep loading, validation, posting, and formatting in this one worker module; do not create a
generic notification framework.

Add the worker to `FrontmanServer` exports. Configure disabled defaults in `config/config.exs`, a test
webhook plus `req_options` in `config/test.exs`, and strict production parsing of
`FRONTMAN_TASK_SUMMARY_NOTIFICATIONS_ENABLED` in `runtime.exs`. Pass the existing task-summary webhook
local to both this worker and `SendAgentFeedbackToDiscord`.

**Verify**:

```bash
make -C apps/frontman_server strict-compile
```

Expected: production and test compilation pass without warnings or boundary violations.

### Step 2: Enqueue atomically from successful terminal persistence

Modify the existing `record_interaction_row/2` transaction in `Tasks` rather than adding a caller-side
hook. Alias `SendTaskSummaryToDiscord`. After the task timestamp update, invoke a private helper that
inserts a job only for `agent_completed` while the feature is enabled.

The helper must receive the inserted `%InteractionSchema{}` so it uses the persisted positive
`turn_number`, not the untrusted input map. Convert `{:ok, %Oban.Job{}}` to `:ok`; propagate
`{:error, changeset}` so the enclosing task transaction rolls back. Leave the existing broadcast
after `Repo.transact/1` unchanged.

Add tests in `tasks_test.exs` that temporarily enable the worker and assert:

1. `record_execution_outcome(..., :completed)` inserts exactly one job with user, task, and turn IDs;
2. failed, cancelled, terminated, paused, response, and tool interactions insert no summary job;
3. disabled configuration inserts no job;
4. completion interaction and Oban job are committed together;
5. the existing PubSub interaction still broadcasts after a successful commit.

Restore application config in `on_exit` to avoid leaking global state between async tests. Mark tests
that mutate application config `async: false` or isolate them in a non-async module.

**Verify**:

```bash
make -C apps/frontman_server test
```

Expected: all tests pass and no existing interaction lifecycle behavior changes.

### Step 3: Build a stable per-turn summary snapshot

In the worker, load the user, create `Scope.for_user/1`, and call `Tasks.get_task/2`. Use
`Tasks.History.new/1` plus `History.attributed_rows!/1` to associate nil-turn user-message rows with
their owning turn. Select only:

- rows whose own `turn_number` is at most the job turn; and
- user-message rows whose attributed `turn_row.turn_number` is at most the job turn.

Exclude unclaimed user messages and all later turns. Assert that the selected rows contain one
`agent_completed` for the requested turn before posting. Keep all selection bounded by the task's
existing loaded interaction list; do not add another database scan.

Port the old embed behavior onto typed rows. The timing field's "Last interaction" becomes the
requested completion row's persisted timestamp, not whatever interaction happened most recently by
worker execution time.

Add worker tests covering:

1. exact embed parity with the old notifier test;
2. successful 2xx POST;
3. non-2xx and transport failures return errors for Oban retry;
4. missing user/task and missing requested completion discard without POST;
5. queued/unclaimed user messages and later-turn rows do not appear in an earlier summary;
6. two completed turns create two independently unique job identities;
7. repeated insertion for the same task and turn is unique;
8. no task delivery-state column or follow-up database write is required.

**Verify**:

```bash
make -C apps/frontman_server check
make -C apps/frontman_server build
```

Expected: all server tests, formatting, Credo, and production compilation pass.

### Step 4: Reduce Frontman Notifier to stargazers only

Only after server tests pass:

- remove `TaskSummaries` from `FrontmanNotifier.run_once/0` and update types/docs;
- delete `TaskSummaries`, its test, and `Database`;
- remove task/database environment readers from `Config`;
- remove Postgrex from `mix.exs` and regenerate `mix.lock` through Mix;
- delete `apps/frontman_notifier/rel/env.sh.eex` because only the server reads the shared webhook;
- remove database and task settings from notifier `env.template`;
- remove database discovery/shared-webhook setup from notifier `setup.sh`;
- remove the shared-env check from notifier `build-and-deploy.sh`;
- remove PostgreSQL coupling from the notifier systemd unit, retaining network ordering;
- update the README to describe a stargazer-only worker;
- change `ensure-shared-discord-env.test.sh` to validate only the server release env hook.

Keep `FrontmanNotifier.State`, its test, state path, release, service, and deployment workflow for
stargazer deduplication.

**Verify**:

```bash
make -C apps/frontman_notifier precommit
bash infra/production/ensure-shared-discord-env.test.sh
rg -n "TaskSummaries|FRONTMAN_NOTIFIER_TASK_|FRONTMAN_NOTIFIER_DATABASE|DATABASE_URL|DISCORD_TASK_SUMMARIES" apps/frontman_notifier infra/production/notifier
```

Expected: checks exit 0 and `rg` returns no matches.

### Step 5: Update deployment templates and changelog

Add `FRONTMAN_TASK_SUMMARY_NOTIFICATIONS_ENABLED=false` to both server slot templates in
`infra/production/server-setup.sh`. Keep the shared webhook out of slot env files.

Update `CHANGELOG.md` directly because these Elixir apps are not Changesets workspaces. State that
successful turn completion now atomically queues a task summary in Frontman Server, the destination
is unchanged, polling/idle delay is gone, and Frontman Notifier remains responsible for stargazers.

Do not add cross-workflow dependencies or combine deployment workflows. The staged operational
sequence below uses their existing path filters.

**Verify**:

```bash
bash -n infra/production/server-setup.sh \
  infra/production/notifier/setup.sh \
  infra/production/notifier/build-and-deploy.sh
bash infra/production/ensure-shared-discord-env.test.sh
git diff --check
```

Expected: all commands exit 0.

### Step 6: Perform a three-stage production handoff

This step is manual. Never merge the complete combined diff in one PR: both independent workflows
would run without ordering guarantees. Use the two PRs defined in Git workflow.

#### Stage A — deploy the server producer disabled

1. Confirm the existing shared webhook file is readable by both server slots without printing its
   value.
2. Add `FRONTMAN_TASK_SUMMARY_NOTIFICATIONS_ENABLED=false` to both live slot env files.
3. Merge and deploy PR 1 only. The old notifier remains active and summaries continue through its
   existing poller.
4. Verify the new worker module is present, no cron plugin exists, the flag is false, and completing a
   canary turn creates no `SendTaskSummaryToDiscord` job.

#### Stage B — remove notifier task polling

5. Merge and deploy PR 2 only after Stage A passes.
6. Verify `frontman-notifier` is active, stargazer checks continue, and logs contain no task-summary
   check or PostgreSQL connection.
7. Accept and record the notification gap beginning at this point. Do not run both producers to avoid
   duplicate Discord messages.

#### Stage C — enable server completion events

8. Choose a low-traffic window and verify the active server has no running agent executions using the
   same `SwarmAi.active_count(FrontmanServer.AgentRuntime)` RPC used by `deploy.sh`. If it is nonzero,
   wait; completions on the old disabled process during blue/green drain are not recoverable without
   polling.
9. Set `FRONTMAN_TASK_SUMMARY_NOTIFICATIONS_ENABLED=true` in both live slot env files.
10. Dispatch the server deployment workflow so the inactive slot starts with the flag enabled and the
    normal readiness/switch/drain process runs.
11. Complete one canary turn. Verify exactly one Oban job with its task and turn identity succeeds and
    exactly one summary appears immediately in the existing Discord channel/thread.
12. Complete a second turn on the same task. Verify it produces one separate summary for the second
    turn and does not reuse the first turn's job identity.
13. Send agent feedback and verify it still reaches the same destination.
14. Confirm there is no hourly task-summary cron entry and no task-summary activity in notifier logs.

Keep the previous notifier release and DETS file for at least 24 hours. Do not delete old state during
this change.

**Expected**: no overlap between producers, a recorded bounded gap only between Stages B and C, and
one immediate Discord summary per successful post-enable turn.

### Step 7: Run final gates

```bash
make -C apps/frontman_server check
make -C apps/frontman_server build
make -C apps/frontman_notifier precommit
bash infra/production/ensure-shared-discord-env.test.sh
git diff --check
git status --short
```

Expected: all commands exit 0. Only in-scope files, plan files, and the pre-existing `mise.toml`
modification appear.

## Done criteria

- [ ] No task-summary cron, timer, poll, idle threshold, lookback, or candidate query exists in
      Frontman Server.
- [ ] A successful `agent_completed` write and its Oban job commit atomically.
- [ ] No failed, cancelled, terminated, or paused outcome queues a "done" summary.
- [ ] Job identity is `task_id` plus `turn_number`; two completed turns on one task produce two jobs.
- [ ] Each worker summary contains only interactions attributed through its triggering turn.
- [ ] Task summaries and agent feedback use the unchanged
      `DISCORD_TASK_SUMMARIES_WEBHOOK_URL` from `/opt/frontman/shared/discord.env`.
- [ ] Frontman Notifier is stargazer-only and no longer connects to PostgreSQL.
- [ ] No migration or task delivery-state column was added.
- [ ] Server, notifier, shell, formatting, Credo, test, and production compile gates pass.
- [ ] The staged production canary produces exactly one immediate message per completed turn in the
      existing channel/thread.
- [ ] `plans/README.md` is marked DONE only after Stage C verification.

## Rollback

1. Set `FRONTMAN_TASK_SUMMARY_NOTIFICATIONS_ENABLED=false` in both server slot env files and roll the
   server back/redeploy so no new completion jobs are inserted.
2. Point `/opt/frontman-notifier/current` to the recorded pre-cleanup release and restart
   `frontman-notifier`; its untouched DETS file resumes old deduplication.
3. Confirm only the old notifier produces task summaries before ending rollback.
4. Keep failed/completed Oban jobs for diagnosis. Do not replay them while the notifier poller is
   active.

## STOP conditions

Stop and report if:

- Product expects notifications for tasks that end only in failure, cancellation, termination, or
  pause. This plan implements successful "done" events only.
- Product expects only one lifetime notification per task rather than one per completed turn.
- The completion transaction cannot include `Oban.insert/1` without moving the existing PubSub
  broadcast inside the transaction.
- A stable through-turn snapshot cannot be built from `Tasks.History` without raw SQL or unbounded
  queries.
- The existing webhook variable or shared file must move or change value.
- Production cannot perform the ordered disabled-server → notifier-cleanup → enabled-server handoff.
- The active server has executions that cannot drain before Stage C.
- Any verification fails twice after a reasonable correction.
- The implementation requires modifying the pre-existing `mise.toml` change.

## Maintenance notes

- The kill switch is operationally useful after cutover; keep it strict and default false outside
  explicitly enabled production environments.
- A new terminal outcome notification policy should add an explicit event type. Do not silently fold
  failures or pauses into "done."
- Oban is used for durable delivery and retry, not time-based detection.
- The old DETS task keys can be removed in a later irreversible cleanup after rollback confidence;
  that cleanup is intentionally not part of this migration.
