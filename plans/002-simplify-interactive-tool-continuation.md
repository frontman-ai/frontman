# Plan 002: Remove timeout-driven pause and consolidate task continuation

> **EXECUTION REVIEW, 2026-09-06:** The full plan is BLOCKED on admission design. Do not implement Step 4 or the proposed nonwaiting-admission amendment. Independent review found a lock inversion and an incomplete finishing handoff. The lead authorized only the independent timeout/recovery subset for isolated implementation and verification. The execution decision near the end of this document overrides the original target design. No claim of full completion is permitted.

> **Executor instructions:** Read this plan completely before implementation. Preserve the deletion goals and the behavior tests together. Do not introduce a replacement workflow engine.
>
> **Drift check:** Run `git diff --stat b54232d9..HEAD -- apps/swarm_ai apps/frontman_server libs/client libs/frontman-client libs/frontman-protocol`. Compare changed code with the excerpts in this plan. Also inspect uncommitted changes. This plan describes the working tree inspected on 2026-09-05, not an isolated clean checkout.

## Status

- Priority: P1
- Effort: L, delivered in ordered changes
- Risk: HIGH, because this crosses execution, persistence, transport, and cancellation
- Category: correctness and architecture
- Planned at: `b54232d9`, 2026-09-05
- Depends on: none
- Related: Plan 001 also touches `Tasks.record_execution_outcome/4`. Preserve its completion notification work if it lands first.
- Implementation status: BLOCKED on admission redesign. Independent subset approved at `ec585f78` on 2026-09-06.
- Execution evidence: [delegation and review report](002-execution-review.md). All team agents are closed.
- Research status: scoped source exploration complete. Runtime tests were not executed during planning.

## 1. Objective

Interactive tools wait for human input without an execution deadline. An answer continues the same turn, including after reconnection or supported server shutdown recovery.

Achieve this by removing the timeout-pause mechanism. Do not add durable pause events, idle timers, worker leases, a second queue, or a new coordinator process.

Keep these concepts separate:

- **Turn:** the persisted unit of conversation, identified by `turn_number`.
- **Execution:** the temporary process that advances a turn.
- **Pending tool call:** a persisted call without its canonical result.
- **Connection:** a transport for commands, results, and notifications.

A turn can remain active while its execution waits for an answer. A missing execution does not, by itself, finish a turn.

### Important choice: retain the parked executor

The first implementation keeps the existing executor blocked in its receive loop for interactive tools. It does not retire that process after an idle interval.

A blocked BEAM process does not poll or call the LLM. It retains memory, including loop history. This is a deliberate resource tradeoff.

This choice removes more machinery than immediate worker retirement. Retirement would require recovery of partially executed batches, serial dispatch position, and result-arrival handoffs.

Serial execution currently persists client tool calls when dispatch reaches them. Later calls can exist only in the assistant response metadata. Do not introduce that additional recovery protocol here.

This is a correction to the earlier discussion: resource release is optional, not necessary for a valid human wait. The existing restart path remains important.

The project style guide normally forbids unbounded waits. Record the narrow, explicitly requested exception for `Interactive` tools. Keep finite limits for execution, transport, and control-plane operations.

## 2. Incident and evidence

The local database contained task `05c28a54-e00a-424d-93d4-296e1d446f59`, titled “WordPress Platform Picker Redesign.”

Its fifth turn requested clarification through `question` at `2026-09-05T19:42:59Z`. At `19:44:59Z`, the server wrote a timeout result and `agent_paused`. No answer appeared in persisted history.

The final turn read one source file and asked the question. It made no edits. Earlier turns completed normally.

This establishes a server-side timeout. It does not establish whether the browser displayed the question correctly.

### Relevant current code

`libs/frontman-protocol/src/FrontmanProtocol__Tool.res:22`:

```rescript
type executionMode = Synchronous | Interactive
```

`libs/client/src/tools/Client__Tool__Question.res:6` declares `Interactive`.

`apps/frontman_server/lib/frontman_server/tools/mcp.ex:42`:

```elixir
defp timeout_policy("Interactive"), do: {120_000, :pause_agent}
defp timeout_policy(_), do: {@default_timeout_ms, @default_on_timeout}
```

`apps/swarm_ai/lib/swarm_ai/parallel_executor.ex:188`:

```elixir
:pause_agent ->
  cancel_remaining(Map.delete(pending, ref), awaiting, task_supervisor)
  {:halt, {:timeout, exec.tool_call.id, exec.tool_call.name, exec.timeout_ms}}
```

`apps/frontman_server/lib/frontman_server/tasks.ex:397` handles that halt by recording an error result and a terminal pause outcome.

`apps/frontman_server/lib/frontman_server/tasks/history.ex:14`:

```elixir
@terminal_types [:agent_completed, :agent_error, :agent_paused]
```

`apps/frontman_server/lib/frontman_server/tasks.ex:475` has a different shutdown rule:

```elixir
defp keeps_turn_open_after_restart?(%Interaction.ToolCall{tool_name: "question"}), do: true
defp keeps_turn_open_after_restart?(%Interaction.ToolCall{}), do: false
```

`apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex:491` branches on physical executor presence:

```elixir
defp resume_after_tool_result(:notified, socket, _scope, _task_id), do: socket

defp resume_after_tool_result(:no_executor, socket, scope, task_id) do
  case Tasks.get_active_turn_unresolved_tool_calls(scope, task_id) do
    {:ok, _turn_number, []} -> resume_agent(socket, scope, task_id)
    {:ok, _turn_number, [_ | _]} -> socket
    {:ok, :no_active_turn} -> socket
  end
end
```

The repository already contains recovery tests for multiple unresolved tools. It also contains a database uniqueness constraint for `{task_id, turn_number, tool_call_id}` results.

## 3. Architecture discovered

### Current normal path

1. `TaskChannel.process_prompt/3` accepts a prompt through `Tasks.submit_user_message/2`.
2. Prompt acceptance returns an ACP response immediately. It does not wait for task completion.
3. `wake_runner/2` sends a channel-local message to start a turn.
4. `Tasks.claim_next_turn/2` locks the task row and assigns accepted messages to a new turn.
5. `Tasks.Execution.start/8` reconstructs model input, resolves tools, and constructs a Swarm loop.
6. `SwarmAi.Runtime` admits one execution process per task on the local runtime.
7. `ToolExecutor` builds `Sync` descriptors for backend tools and `Await` descriptors for client tools.
8. `ParallelExecutor` executes descriptors in serial or parallel order.
9. A client call registers its waiter before persisting and broadcasting its tool-call interaction.
10. The channel creates an MCP request ID and remembers its mapping to the durable tool-call ID.
11. A response passes schema checks, then `Tasks.resolve_tool_request/5` persists the canonical result.
12. `Execution.notify_tool_result/2` sends that result to the registered waiter.
13. The loop continues after its batch completes.

### Current recovery path

1. A connection loads history and completes MCP initialization.
2. The channel redispatches unresolved tool calls for the active turn.
3. Results still enter `Tasks.resolve_tool_request/5`.
4. If no waiter exists, the channel checks unresolved calls and calls `Tasks.resume_execution/3`.
5. The execution reconstructs its input from persisted history.

This is existing resumability, not a missing subsystem.

### A recovery gap to close without adding batch state

`Tasks` persists the assistant response before tool dispatch. That response contains every declared tool call.

However, `unresolved_tool_calls_for_turn/2` queries only standalone tool-call rows. Serial calls after an unanswered question do not yet have those rows.

Consequently, a shutdown can preserve the question but overlook later declared calls. A subsequent LLM request can contain calls without results.

Use the persisted assistant declarations to close interrupted calls conservatively. Do not add a serial-position checkpoint or replay those operations automatically.

### Current conflicts

| Conflict | Evidence | Consequence |
|---|---|---|
| `Interactive` becomes a deadline policy | `tools/mcp.ex:28-43` | Human delay becomes failure |
| Timeout halts an entire batch | `parallel_executor.ex:188-225` | One unanswered question cancels siblings |
| Process pause becomes a finished turn | `tasks.ex:397-415`, `history.ex:14` | Later answers cannot resolve an active call |
| Recovery uses a tool name instead of metadata | `tasks.ex:475-476` | A second interactive tool gets different recovery behavior |
| Transport owns continuation choices | `task_channel.ex:491-512`, `967-972` | Lifecycle reasoning requires socket state and persisted history |
| Tool deadline data exists twice | `SwarmAi.Tool`, execution descriptors | A field in the model-facing tool object appears authoritative but does not drive execution |
| Canonical storage and local timeout results can differ | `ToolExecutor.handle_timeout`, `ParallelExecutor.handle_deadline` | A result-arrival race can give the LLM a different result from history |

The last item is a code-path risk, not an observed cause of this incident. Cover it with a deterministic regression test.

## 4. Timeout inventory: delete selectively

| Timer or setting | Actual owner and purpose | Decision |
|---|---|---|
| Interactive 120-second deadline | MCP metadata adapter to `ParallelExecutor` | Remove |
| Synchronous client deadline, currently 600 seconds | `ParallelExecutor` | Keep |
| Backend tool deadlines, currently 30 or 60 seconds | Backend declarations to `ParallelExecutor` | Keep |
| Backend HTTP receive timeout | `tools/web_fetch.ex`, Req | Keep. This bounds a network operation inside a tool |
| MCP initialization timer, 30 seconds | `TaskChannel` and `MCPInitializer` | Keep. This bounds discovery, not human input |
| ACP request timer, 120 seconds | `FrontmanClient__ACP__Protocol.sendRequest` | Keep in this plan. It bounds command acknowledgement |
| Phoenix push timeout | Phoenix transport | Keep. Do not treat its expiry as a tool result |
| LLM stream stall timer | `Tasks.StreamStallTimeout` | Keep. This bounds silence from the provider |
| Provider HTTP and stream timeouts | Provider client and ReqLLM | Keep |
| Swarm `Loop.Config.timeout_ms` | Declared overall timeout with no execution read found | Remove after repository-wide usage verification |
| Swarm `step_timeout_ms` | Passed to the generic `LLM.stream` protocol | Keep. Frontman's implementation ignores those options, but other protocol implementations can use them |
| Runtime five-second calls and finishing wait | `SwarmAi.Runtime` | Keep |
| Retry backoff timer | `Tasks.RetryCoordinator`, currently hosted by the channel | Keep in this plan. This is a known transport-lifetime coupling, not a human-wait timer |
| Client source-location deadline | Task reducer source-location effect | Keep. Unrelated operation |

No MCP relay execution timer appeared in the inspected client relay path. Do not claim that the ACP acknowledgement timer caused this task failure.

## 5. Target ownership and API

### `Tasks` owns continuation decisions

Introduce one public decision entry in the existing context, named `Tasks.advance_execution(scope, task_id, execution_context)`.

Replace overlapping start/resume decisions with this entry. Do not add a `TaskCoordinator` module or process.

Its decision table is:

| Persisted state / runtime | Decision |
|---|---|
| Active turn with a live execution | Leave that execution in control |
| Active turn, no execution, unresolved calls | Wait for valid results and connection delivery |
| Active turn, no execution, all calls resolved | Reconstruct and resume the same turn |
| No active turn, accepted messages exist | Claim and start the next turn |
| No active turn, no accepted messages | No operation |
| Terminal old turn with a late result | Do not reopen it |

Use the persisted model and agent for a resumed turn. Connection metadata must not replace them.

Keep scope checks and the existing row lock for turn claims. Runtime registration remains the local execution admission guard.

The channel calls this context entry after prompt acceptance, MCP readiness, session load, result acceptance, and existing terminal wake points. It no longer chooses start versus resume.

The channel still owns MCP readiness and transport request correlation. Those are not duplicate task state.

Keep channel `active_turn` where it verifies streamed message attribution. Remove its use as an independent admission decision. Do not delete a useful stale-turn assertion merely to reduce lines.

### Tool results have one persisted meaning

Retain `Tasks.resolve_tool_request/5` as the canonical result writer.

Return `{:ok, interaction}` to callers. Keep physical waiter delivery private to `Execution`; do not expose `:notified` or `:no_executor` through the context API.

After accepting a client result, call `advance_execution/3` regardless of waiter presence. A live execution already received the canonical result through the resolver.

Backend completion and finite timeout paths must also return the stored canonical result to the loop. Do not fabricate a second local result after persistence chooses a winner.

Keep the database uniqueness constraint. A duplicate returns the stored winner without starting another execution or altering its content.

### `Interactive` remains the only designation

Preserve `executionMode` in the parsed server MCP tool definition. Derive the executor deadline at the adapter boundary:

- `Synchronous`: a positive millisecond deadline.
- `Interactive`: `:infinity`, represented by no timer in `ParallelExecutor`.

Do not add `never_timeout`, `human_wait`, or another policy enum.

Persist the selected execution mode in the existing tool-call JSON data at dispatch. Use that snapshot for recovery.

Do not infer recovery policy from the current connection's tool list. That list can change between dispatch and reconnect.

### A parked executor is not a terminal outcome

Remove new production of `agent_paused` for tool waits. Remove Swarm's timeout-specific halt path.

The active turn remains open. The pending question stays answerable. The UI can show the existing question form without a new lifecycle event.

Keep the historical `AgentPaused` decoder and terminal projection. Old timeout records already contain error results. Reinterpreting them as open would revive completed history incorrectly.

No automatic repair of the incident task is included. Its old timeout remains a historical outcome. The user can send a new instruction.

## 6. Deletion ledger

The implementation report must account for each row.

| Remove | Replacement / reason |
|---|---|
| `on_timeout: :error | :pause_agent` policy fields | A finite deadline produces an error. An infinite wait has no expiry |
| Backend `on_timeout/0` behavior and identical implementations | All inspected backend implementations return `:error` |
| Timeout metadata on `SwarmAi.Tool` | Execution descriptors already carry the operational deadline |
| MCP `timeout_policy/1` returning two values | Preserve mode and derive one descriptor deadline |
| `ParallelExecutor.cancel_remaining/3` for timeout-pause | No interactive deadline can cancel the batch |
| `{:halt, {:timeout, ...}}` return path | Tool batches return their results |
| Pause-only `Loop.pause/2` and executor branches | Remove after confirming there are no other callers |
| `handle_timeout` clauses for pause and sibling cancellation | Retain only finite operation error handling |
| New timeout-generated `AgentPaused` writes | Pending call remains unresolved |
| `TaskChannel.resume_after_tool_result/4` and `resume_agent/3` | One context continuation entry |
| Channel admission gate based on `active_turn == nil` | Persisted history decides admission |
| Exported waiter-presence result variants | Private notification optimization |
| Runtime question-name recovery branch | Persisted execution mode |
| Unused overall loop timeout config | No replacement |

### Small additions allowed

- An optional timer reference and `:infinity` deadline in execution descriptors.
- A persisted execution-mode field inside tool-call JSON.
- One continuation entry in `Tasks`, assembled from existing functions.
- Regression tests and narrowly bounded historical decoding.

A single finite-timeout callback can remain on execution descriptors. It performs application-specific persistence, not timeout policy selection.

Change that callback to return the canonical `ToolResult` instead of `:ok`. Then `ParallelExecutor` consumes that result directly.

Do not add a generic result bus or callback framework to remove this one necessary persistence boundary.

**Size gate:** changed production `.ex` and `.res` files must have fewer added lines than removed lines. Count tests and documentation separately. If this requires more machinery, stop and revise the design rather than compress code artificially.

## 7. Behavioral contracts

### Answers, prompts, and cancellation

- An MCP answer resolves its identified tool call and continues the same turn.
- A normal ACP prompt remains an accepted message for the next turn. Preserve existing queue semantics.
- Do not interpret an arbitrary new prompt as a question answer. It lacks the tool-call identity and schema.
- The question's custom-text field is an answer path.
- Explicit cancellation closes pending calls and the active turn, even when no execution exists after restart.
- A late answer after cancellation cannot reopen a turn or replace the cancellation result.
- A parked worker remains cancellable through the existing runtime process termination path.

The phrase “next message resumes” refers to a valid response to the pending interaction. Changing plain prompt semantics is a separate product decision.

### Serial and parallel tools

- Serial tools preserve original dispatch order. An interactive call blocks later calls until its answer arrives.
- Parallel tools preserve result order. Other tools can complete or hit their own finite deadlines while an interactive call waits.
- No interactive wait cancels another tool.
- The LLM receives the next request only after every tool in its batch has a result.
- A deadline applies to the operation that owns it, not to the whole turn.

### Recovery boundaries

- Reconnection can redispatch an unresolved interactive call using the same durable ID and a new transport ID.
- A successful synchronous mutation must not be replayed because a human took longer than two minutes.
- Shutdown recovery uses the persisted execution mode, not the name `question`.
- Shutdown treatment of non-interactive calls remains conservative: record interruption rather than assume replay is safe.
- Include declared-but-undispatched calls in cancellation and shutdown cleanup. They receive an interruption result, not automatic execution.
- Preserve only dispatched interactive calls whose stored mode supports recovery. An undispatched call has no such dispatch snapshot.
- Process or node failure does not imply exactly-once external side effects. Do not claim that guarantee.
- Recovery requires a connected client for browser tools. No autonomous browser connection manager is added.

### Publication and admission races

Preserve these existing protections:

1. Register a live tool waiter before publishing its call.
2. Persist a result before notifying the waiter.
3. Keep execution registration through terminal event persistence.
4. Keep the `:finishing` handoff introduced by commit `b54232d9`.
5. Reload persisted history before deciding to resume.
6. Treat `:already_running` as another caller winning admission, not as a failed turn.

Do not await worker termination while holding a task-row lock. Terminal persistence can need that same row.

A repeated or delayed `advance_execution` call must re-read current history. It must not start a previously built loop from an obsolete turn snapshot.

If concurrent admission still starts duplicate LLM requests, stop at that regression. Do not add polling or an unchecked `running?` guard as a race fix.

## 8. Compatibility and exclusions

### Historical data

`Interaction.ToolCall` currently lacks an execution-mode field. Its embedded schema and `attrs/1` are in `tasks/interaction.ex:837-877`.

Add `execution_mode` as a nullable `Ecto.Enum` field with `:synchronous` and `:interactive` values. Null represents historical data only.

Pass the parsed mode through `ToolExecutor.start_mcp_tool`, `Tasks.request_client_tool`, and `Interaction.ToolCall.attrs`. Require an explicit valid mode on new dispatch writes.

The schema uses `PolymorphicEmbed`. Do not assume its load path runs changesets. Do not introduce a custom JSON decoder.

Add a small `Interaction.ToolCall.execution_mode/1` accessor. It returns the stored mode, with the following fallback for historical rows:

- Old `question` rows mean `Interactive`.
- Other old rows keep historical synchronous treatment.

Keep this exception inside that accessor, with an explicit compatibility comment. The runtime shutdown handler must contain no tool-name exception.

Missing discovery metadata still means `Synchronous`, matching existing clients. Reject unsupported declared modes at the existing MCP metadata boundary. Do not silently convert malformed modes.

Do not bulk-update existing interactions or delete old pause outcomes. A backfill adds operational risk without improving the new runtime.

### Published Swarm API

`apps/swarm_ai/mix.exs` defines a Hex package at version `1.0.0`. Removing struct fields is a public API change.

Update its README, examples, tests, and changelog. Mark the release as breaking. Do not publish it as a patch release.

The server uses the local Swarm source. Coordinate the eventual package version with the maintainer before publication. Do not add ignored compatibility fields that preserve misleading policy choices.

### Explicitly outside this implementation

- Provider retry algorithm changes or removal of `RetryCoordinator`.
- Moving retry timers off the channel. This is a known lifecycle coupling, but it is not needed to remove human-wait expiry.
- Autonomous execution of browser tasks with no connected client.
- Multi-node execution fencing. Existing runtime registration is local.
- Immediate worker retirement or memory eviction while awaiting a person.
- A redesign of the client question UI for simultaneous question forms. It currently stores one `pendingQuestion`.
- Rewriting ACP transport timers or introducing new protocol messages.
- Unrelated marketing, feedback, WordPress, or notifier changes.

Do not advertise the result as removal of every lifecycle concern from the channel. It removes tool continuation policy; retry hosting and transport readiness remain explicit exceptions.

## 9. Files and conventions

### Production scope

- `apps/swarm_ai/lib/swarm_ai.ex` and `apps/swarm_ai/lib/swarm_ai/runtime.ex`, only the admission factoring described below
- `apps/swarm_ai/lib/swarm_ai/parallel_executor.ex`
- `apps/swarm_ai/lib/swarm_ai/tool_execution/{sync,await}.ex`
- `apps/swarm_ai/lib/swarm_ai/{tool,executor,loop,testing}.ex`
- `apps/swarm_ai/lib/swarm_ai/loop/config.ex`
- `apps/frontman_server/lib/frontman_server/tools/{mcp,backend,agent_feedback,web_fetch,todo_write,get_tool_result}.ex`
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/lib/frontman_server/tasks/{execution,history,interaction,interaction_schema}.ex`
- `apps/frontman_server/lib/frontman_server/tasks/execution/tool_executor.ex`
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/lib/agent_client_protocol/history.ex`, only historical pause compatibility and replay coverage
- `libs/client/src/state/Client__Task__Reducer.res`, only if cancellation or pending-question behavior needs correction

Keep missing-mode compatibility inside `Interaction.ToolCall`. No new decoder module is in scope.

Telemetry formatters that pattern-match the removed Swarm pause status are also in scope. Limit changes to obsolete status clauses and their tests.

### Tests and documentation scope

- Existing Swarm tests and `apps/swarm_ai/test/swarm_ai_test.exs`
- `apps/frontman_server/test/frontman_server/{tasks_test,tools_test}.exs`
- `apps/frontman_server/test/frontman_server/tasks/**`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`
- Existing ACP history tests and tool fixtures under server `test/support`
- `libs/client/test/Client__Task.test.res` and its generated `.res.mjs`
- Existing client integration tests for the question tool
- Swarm README, changelog, and `lib/swarm_ai/spec.md`
- Relevant `.changeset/*.md`
- `agent_docs/elixir-style.md`, only the narrow human-wait exception
- `plans/README.md` and this plan's status

Do not edit generated ReScript directly. Use the compiler. Do not change dependencies.

### Conventions

Read `AGENTS.md`, `apps/frontman_server/AGENTS.md`, and `agent_docs/elixir-style.md` before code changes.

Use `%Scope{}` on context boundaries. Use guarded function clauses and `case` for control flow. Persist related changes transactionally. Broadcast after commit.

Keep ReScript side effects in the reducer. Use typed bindings and Sury schemas. Match the existing `Client__Task.test.res` patterns.

## 10. Commands and environment

The command recipes were inspected. `make -n` confirmed the main build and test entry points. No baseline pass is claimed.

| Purpose | Command from repository root | Expected result |
|---|---|---|
| Worktree | `make worktree-create BRANCH=refactor/interactive-tool-continuation` | Isolated worktree created |
| Swarm tests | `make -C apps/swarm_ai test` | Exit 0 |
| Swarm checks | `make -C apps/swarm_ai check` | Exit 0 |
| Server tests | `make -C apps/frontman_server test` | Exit 0, test database only |
| Server strict compilation | `make -C apps/frontman_server strict-compile` | Exit 0, no warnings |
| Server checks | `make -C apps/frontman_server check` | Exit 0 |
| ReScript compilation | `make rescript-build` | Exit 0 |
| Client tests | `make -C libs/client test` | Exit 0 |
| Frontman client tests | `make -C libs/frontman-client test` | Exit 0 |
| Protocol tests | `make -C libs/frontman-protocol test` | Exit 0 |
| Final server precommit | `make -C apps/frontman_server precommit` | Exit 0, inspect formatter and lockfile effects |
| Whitespace | `git diff --check` | No errors |

Containerized worktrees require `./bin/pod-exec` before toolchain commands. File operations and git remain on the host.

Server test recipes create and migrate the test database. Do not point them at development or production data.

The precommit recipe can format files and unlock unused dependencies. Inspect its diff. Do not include unrelated changes.

Use the repository changeset workflow. Do not push, publish, or create a PR without authorization.

## 11. Implementation steps

### Step 1: Establish behavior tests and the deletion baseline

Create the worktree. Inspect local changes before copying any required work into it. Do not overwrite the user's active marketing or feedback work.

Record production line counts for the scope. Record current `on_timeout`, pause, and continuation call sites.

Run the existing Swarm, server, and client tests. Separate pre-existing failures from this work.

Add the targeted regression tests from Section 12. First demonstrate that the interactive timeout regression fails under current behavior.

Use a short finite sibling deadline and an infinite interactive descriptor. Do not make the suite wait two real minutes.

For the current code, the test can fail at unsupported `:infinity` construction. Retain a separate MCP mode assertion that exposes the actual 120-second mapping.

**Verify:** `make -C apps/swarm_ai test`, `make -C apps/frontman_server test`, `make -C libs/client test`. Record baseline failures and the expected new regression failure.

### Step 2: Remove the timeout-pause execution policy

Remove the policy enum from backend declarations, MCP conversion, Swarm tool metadata, and descriptors.

Keep deadlines only on the execution descriptors. Use `pos_integer() | :infinity` for the waiting descriptor deadline.

In `ParallelExecutor`, create a timer only for finite deadlines. Store `nil` for an absent timer. Use two small clauses for timer cancellation.

Delete pause-driven batch cancellation and halt returns. Simplify serial execution to collect normal results without halt propagation.

Retain finite timeout termination of the affected synchronous task. Retain process monitors, result ordering, and crash handling.

Simplify the application timeout callback to one finite-error path. Return its canonical stored result to the executor.

Change successful backend persistence paths to return the canonical winner too. Preserve schema and error checks.

Remove pause-only loop status producers, telemetry branches, and examples after checking every caller. Preserve historical server event decoding.

Remove unused `Loop.Config.timeout_ms` after the full usage search. Keep `step_timeout_ms` for generic LLM implementations.

**Verify:** `make -C apps/swarm_ai check` and `make -C apps/frontman_server test`. Interactive waits survive a finite sibling deadline. Finite tools still fail correctly.

### Step 3: Make recovery follow persisted tool mode

Preserve parsed MCP execution mode. Add the mode snapshot to persisted tool-call JSON through the dispatch adapter.

Add the historical accessor described in Section 8. Keep its missing-field exception isolated from current execution policy.

Replace `keeps_turn_open_after_restart?/1` with a mode-based predicate.

Replace the cleanup-only unresolved-call query with a history projection over declared calls and canonical results. Reuse `Interaction.to_swarm_tool_calls/1` for stored assistant declarations.

Index persisted dispatch rows by tool-call ID. Subtract existing canonical results from the declared calls for the turn.

For shutdown, preserve dispatched interactive calls. Record interruption results for all other unresolved declarations, including calls not yet dispatched.

For explicit cancellation, record interruption results for every unresolved declaration. Do not create fake dispatch rows for tools that never ran.

Use the explicit `turn_number` result-write option for undispatched declarations. Resolve each result through the existing canonical writer.

Preserve conservative handling of interrupted synchronous operations. Do not blindly replay writes.

Retain terminal treatment of historical `AgentPaused` rows. Delete only the new timeout-pause producer and its now-unused imports.

Make cancellation operate on an active persisted turn even when runtime cancellation returns `:not_running`. Reuse existing interruption and cancellation outcome functions.

**Verify:** `make -C apps/frontman_server test`. A non-question interactive fixture survives supported shutdown. Old pause history remains terminal.

### Step 4: Consolidate continuation inside `Tasks`

Build `advance_execution/3` from the existing claim and resume functions. Use the decision table in Section 5.

Move the channel's unresolved-result decision into this context entry. Remove the socket-level `resume_after_tool_result` and `resume_agent` functions.

Hide waiter-presence status inside the result resolver. Update backend callers and concurrency tests to the simpler return tuple.

Make the channel request advancement after accepted results, prompts, readiness, load, and terminal notifications. Keep transport-readiness guards.

Restrict reconnect redispatch to unresolved interactive calls. A new connection must not re-execute an ambiguous synchronous mutation.

A live synchronous wait keeps its finite deadline. Supported shutdown records its interruption through the cleanup path from Step 3.

Keep retry commands explicit. They must not bypass the current retried-error ID and stale-turn checks.

Preserve the finishing-registration handoff from `b54232d9`. Do not remove it as apparent duplication.

Handle the expected `:already_running` admission race explicitly. Surface other start errors through existing error handling.

Do not perform a blocking runtime finishing wait inside a database transaction. Do not reuse a turn snapshot after such a wait.

**Verify:** `make -C apps/frontman_server test` and `make -C apps/swarm_ai test`. Concurrent answers and reconnects cause one continuation. Completion still cannot race the next turn.

### Step 5: Verify the client wait and cancellation contract

Keep the existing question tool and MCP response path. Do not add a new pause notification or resume command.

Ensure that a pending question remains answerable while its tool result is absent. Ensure that explicit question cancellation sends the existing cancel command.

If `CancelTurn` is gated only by `isAgentRunning`, cover a pending-question state too. Do not rename every running flag across the UI.

Preserve queue semantics for ordinary prompts. A question answer does not drain unrelated accepted messages into the current turn.

Keep old `requires_action` support for replay compatibility. New human waits need no terminal `agent_paused` event.

**Verify:** `make rescript-build`, `make -C libs/client test`, `make -C libs/frontman-client test`, and `make -C libs/frontman-protocol test`.

### Step 6: Remove leftovers and document the smaller contract

Update Swarm examples and its breaking-change notes. Add a changeset for Frontman's human-wait correction.

Document the parked-worker memory tradeoff and the narrow style-guide exception. Do not promise worker eviction or autonomous recovery without a connection.

Run the structural deletion checks and all final test commands. Report production additions and deletions separately from tests and documentation.

Update the plan index. Include any remaining compatibility-only code in the implementation summary.

**Verify:** all commands in Section 10 succeed. The structural and size gates in Section 13 pass.

## 12. Test plan

Use existing ExUnit tests and ReScript tests. Do not add a new framework or production timer-injection subsystem.

Use barriers and explicit messages for concurrency tests. Use short real deadlines only for actual deadline behavior.

### Swarm executor

Extend `apps/swarm_ai/test/swarm_ai/parallel_executor_test.exs` and `parallel_tool_execution_test.exs`:

1. An `Await` descriptor with `:infinity` remains pending beyond a finite sibling deadline.
2. Sending its result later completes the batch successfully.
3. A synchronous sibling timeout produces only that sibling's error.
4. A serial interactive call prevents dispatch of the next call until answered.
5. Parallel results retain original call order despite out-of-order arrivals.
6. Cancelling the execution still terminates the parked wait and cleans runtime registration.
7. Stale deadline messages cannot produce another result after completion.
8. A timeout/result race returns the same canonical result that storage selected.

Retain completion-registration tests in `apps/swarm_ai/test/swarm_ai_test.exs`. They protect the latest local commit.

### Server lifecycle and persistence

Extend `tasks/execution_test.exs`, `tasks/history_test.exs`, `tasks/tool_result_concurrency_test.exs`, and `tasks_test.exs`:

1. MCP `Interactive` maps to an infinite wait. Synchronous defaults remain finite.
2. A delayed answer produces no error result or `AgentPaused` interaction.
3. The resumed LLM sees the real answer in the same turn.
4. A new interactive fixture named `approval` survives supported shutdown. No production tool implementation is needed for this test.
5. An old `question` row without mode still exposes its historical recovery semantics through the accessor.
6. An old `agent_paused` row does not reopen its turn.
7. After restart, the first of two pending answers does not resume the LLM. The final answer does.
8. Duplicate and conflicting results return one canonical interaction.
9. Identical tool-call IDs in different tasks cannot cross-deliver results.
10. Cancellation with no live executor closes the active turn and pending calls.
11. An answer concurrent with cancellation cannot reopen a cancelled turn.
12. Concurrent advancement attempts do not create duplicate turns or LLM calls.
13. Resume uses persisted model/agent values, not stale client metadata.
14. A normal accepted prompt stays queued during an unresolved interactive call.
15. Finite timeout persistence and the LLM's tool message agree in both race orderings.
16. A serial batch declares a question followed by a write. Shutdown preserves the dispatched question and records interruption for the undispatched write.
17. After that question's answer, the LLM receives a result for every declared call. The write did not execute during recovery.
18. Cancellation closes declared-but-undispatched calls too, without creating fake dispatch records.

Use `tool_result_concurrency_test.exs` as the model for real concurrent database connections. Clean fixtures as the existing tests do.

### Channel and reconnect

Extend `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`:

1. Prompt acknowledgement arrives before task completion.
2. A question answer still works after reconnection with a new MCP request ID.
3. Old or unknown transport IDs do not resolve another call.
4. A late answer to a terminal call cannot trigger continuation.
5. Multiple result notifications and session loads produce one continuation.
6. Repeated session loads do not redispatch synchronous mutations, including calls whose result was lost with the old connection.
7. A stale channel `active_turn` value cannot independently admit another execution.
8. MCP initialization timeouts retain their current behavior.

### Client

Extend `libs/client/test/Client__Task.test.res`:

1. The pending question survives ordinary waiting without a timeout-induced error.
2. Answer submission resolves its MCP callback once.
3. Question cancellation sends the existing cancel command.
4. Cancellation works with a pending question even if the displayed running state is false.
5. Queued ordinary messages remain queued after an answer.
6. Historical `requires_action` replay remains readable.

The client currently supports one pending question form. Server tests with two pending calls do not prove multi-form UI support. Keep this limitation explicit.

## 13. Machine-checkable completion gates

All must hold:

- [ ] Commands in Section 10 pass, apart from the worktree creation command which runs once.
- [ ] `git diff --check` returns no errors.
- [ ] No new dependency, queue, coordinator process, or persisted lifecycle table exists.
- [ ] New interactive calls have a persisted execution-mode snapshot.
- [ ] Historical pauses remain readable and terminal.
- [ ] Regression tests cover late answers, serial ordering, cancellation, recovery, and result races.
- [ ] The runtime finishing-registration tests still pass.
- [ ] The public result resolver no longer exposes waiter presence.
- [ ] The production deletion total exceeds the production addition total.
- [ ] Only scoped files changed.
- [ ] The index marks this plan DONE only after review.

Structural searches, from the repository root:

```bash
# Expected: no current production timeout-pause policy or producer.
rg -n 'pause_agent|paused_for_tool_timeout|cancel_remaining' \
  apps/swarm_ai/lib apps/frontman_server/lib/frontman_server/tools \
  apps/frontman_server/lib/frontman_server/tasks.ex \
  apps/frontman_server/lib/frontman_server/tasks/execution

# Expected: no socket-level continuation branch.
rg -n 'resume_after_tool_result|defp resume_agent|:no_executor|:notified' \
  apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex

# Expected: no duplicated operational fields on the model-facing tool schema.
rg -n 'field\(:timeout_ms|field\(:on_timeout' \
  apps/swarm_ai/lib/swarm_ai/tool.ex

# Expected: no tool-name exception in the runtime restart policy.
rg -n 'keeps_turn_open_after_restart.*question' \
  apps/frontman_server/lib/frontman_server/tasks.ex

# Expected: a positive deletion margin for changed production source.
git diff --numstat b54232d9 -- 'apps/swarm_ai/lib/**/*.ex' \
  'apps/frontman_server/lib/**/*.ex' 'libs/client/src/**/*.res' \
  | awk '{added += $1; removed += $2} END {print "added", added, "removed", removed; exit !(removed > added)}'
```

For no-match searches, ripgrep exit 1 is the expected result. Keep compatibility explanations out of the searched current runtime paths.

If the base branch advances, use the implementation branch's recorded base commit for the size gate. Exclude unrelated pre-existing changes.

## 14. STOP conditions

Stop and report rather than invent another mechanism if:

- A current consumer depends on timeout-driven Swarm pause beyond the paths recorded here.
- A supposedly unused timeout field has a real execution consumer.
- Package release constraints prohibit the required public Swarm API cleanup.
- Correct recovery requires immediate worker retirement or replay of undispatched serial operations, rather than conservative interruption.
- Admission races require distributed ownership guarantees absent from the existing runtime.
- A change needs blocking runtime calls inside a task-row transaction.
- The new resolver returns a different tool result from persisted history.
- The implementation needs changes outside the scope without a direct call-site reason.
- A focused verification fails twice after a reasonable correction.
- Production code grows instead of shrinking.

Do not use these conditions to skip a required regression. Report the failing invariant and the smallest proposed revision.

## 15. Rejected approaches and retained limits

### Rejected

- Increase the question timeout: preserves the wrong failure mode.
- Add an idle timer that expires only the worker: introduces another handoff race and timer policy.
- Turn every `agent_paused` row into an active turn: changes historical meaning and revives failed calls.
- Retire the worker immediately for each interactive call: requires serial-batch recovery not present in the current resume path.
- Add a durable task scheduler: duplicates existing interaction history, runtime admission, and accepted-message storage.
- Remove all timers: confuses human input with failed computation or transport.
- Remove the `:finishing` runtime state: undoes the verified completion-lifecycle fix in the latest commit.
- Delete MCP request correlation: transport IDs and tool-call IDs serve different lifetimes.
- Replace all client flags with a new state machine: unnecessary for this behavior change.

### Retained limits

A parked worker retains model history in memory. Add eviction only after measurements justify the extra recovery protocol.

Automatic retries remain socket-hosted. Moving them into a server-owned lifecycle is a separate architecture change, not a prerequisite here.

Browser tools still require an available browser. Abrupt node loss and external write ambiguity are not converted into exactly-once execution guarantees.

The client still has a single pending-question form. This plan does not silently claim concurrent interactive UI support.

## Rejected execution amendment: nonwaiting admission, 2026-09-06

**Rejected after independent review. Do not implement this proposal.**

Delegated implementation exposed a necessary boundary in `advance_execution`: the existing `SwarmAi.run` can wait for a finishing worker.

That wait cannot occur under the task-row lock. Building a loop before the wait also permits stale snapshots.

The lead approved factoring existing runtime behavior into two explicit operations:

- `SwarmAi.await_finishing(runtime, task_id)`: the existing bounded finishing wait, used outside the database transaction.
- `SwarmAi.try_run(runtime, loop)`: existing registration-based admission without a finishing wait.

`SwarmAi.run` keeps its existing behavior by composing both. No new timer, process, or state is added.

`Tasks.advance_execution` waits first, then reloads history and admits the fresh loop under the task-row lock.

Independent review rejected this amendment. `Runtime.handle_info(:DOWN)` synchronously persists terminal events and can need the same task-row lock. A caller that holds that lock and calls Runtime creates a lock cycle.

The outside finishing check also has a gap: a running worker can become finishing before admission. The proposed caller can then lose its only wake.

The delegated Swarm owner removed all speculative admission changes. The baseline runtime remains unchanged.

## Authorized independent subset, 2026-09-06

The following work can proceed without the rejected admission redesign:

- Infinite interactive waits and removal of the timeout-pause mechanism.
- Removal of duplicate operational fields from model-facing tool definitions.
- One descriptor `on_error` callback for `:timeout` and `{:crashed, exit_reason}`. It receives appended arguments `[reason, tool_call]` and returns the canonical `ToolResult`.
- Persisted tool-mode snapshots and historical-mode compatibility.
- Conservative cleanup of declared-but-undispatched calls during existing cancellation and supported shutdown handling.
- Client cancellation of a pending question when its displayed running flag is false.
- A narrowly tested stale outbound call guard, without a claim of full dispatch/cancellation fencing.

Preserve existing admission APIs, their invocation points, and the resolver return tuple `{:ok, interaction, :notified | :no_executor}`. Do not introduce `Tasks.advance_execution/3` in this revision.

Preserve current reconnect policy until recovery without shutdown cleanup has a complete design. Interactive-only filtering can otherwise strand an unresolved synchronous call.

Defer no-executor cancellation, fresh-history admission fencing, and guaranteed single continuation under delayed concurrent advancement. These remain required before the full plan can become DONE.

The isolated subset still requires its own complete test review and a net production-code reduction. Do not rename these deferred guarantees as completed work.

## 16. Review checklist

The reviewer must ask:

1. Did the implementation delete the timeout-pause mechanism, or rename it?
2. Can a person answer later without starting a new turn?
3. Does ordinary cancellation still work without a live worker?
4. Does one source of persisted truth decide the result and the active turn?
5. Does the channel request continuation instead of choosing its mechanism?
6. Are serial tools still serial, including a human wait in the middle?
7. Are old records readable without changing their meaning?
8. Is the production code smaller, with the concurrency protections intact?
