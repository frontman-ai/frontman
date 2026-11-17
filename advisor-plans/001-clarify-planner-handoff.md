# Plan 001: Explain the Planner-to-Executor handoff

> Executor: Read this plan before implementation. Read each complete test file before adding tests.
> Stop at a STOP condition. Update the status in `advisor-plans/README.md` after review.
>
> Drift check: `git diff --stat e87074a5..HEAD -- apps/frontman_server/config/config.exs apps/frontman_server/lib/frontman_server/agents/system_prompt.ex apps/frontman_server/test/frontman_server/agents_test.exs libs/client/src/components/frontman/Client__ExecutePlanBanner.res libs/client/test/Client__State__StateReducer.test.res`

## Status

- Priority: P1
- Effort: S, approximately half a day
- Risk: LOW
- Depends on: none
- Category: dx
- Planned at: commit `e87074a5`, 2026-11-15

## Why this matters

Approval text does not switch Planner to Executor. Planner can therefore receive an implementation request without the tools to perform it.
The correct recovery is the existing handoff, not a request to enable write tools.
The product must explain this distinction without changing the permission boundary.

## Current state

[Planner configuration](../apps/frontman_server/config/config.exs#L109-L112):

```elixir
      If the user asks for implementation, produce the plan that implementation agent should follow instead.
      Treat the handoff as an implicit product workflow, not an explicit tool or agent invocation you can trigger.
```

Planner has `tools: %{access: [:read]}` at line 140.
The [prompt composer](../apps/frontman_server/lib/frontman_server/agents/system_prompt.ex#L17-L27) receives the complete agent struct.
It currently uses only its `system` field in the function head.
Add the handoff guidance there so tests exercise the same behavior as production.
Test configuration uses replacement agent prompts, so a production-only prompt assertion will miss this behavior.

[The banner](../libs/client/src/components/frontman/Client__ExecutePlanBanner.res#L13-L16) currently says:

```rescript
        {React.string("Execute plan")}
```

```rescript
        {React.string("Hands the plan to the executor agent")}
```

[The selector](../libs/client/src/state/Client__State__Selectors.res#L228-L240) requires a completed idle Planner turn and a matching session.
[The reducer](../libs/client/src/state/Client__State__StateReducer.res#L460-L475) switches agents explicitly.
Ordinary messages retain the selected agent at lines 410–423.
Preserve both rules.

## Scope and conventions

Modify only:

- `apps/frontman_server/config/config.exs`
- `apps/frontman_server/lib/frontman_server/agents/system_prompt.ex`
- `apps/frontman_server/test/frontman_server/agents_test.exs`
- `libs/client/src/components/frontman/Client__ExecutePlanBanner.res`
- `libs/client/test/browser/Client__ExecutePlanBanner.test.res` (new)
- One user-facing changeset generated through `yarn changeset`

Existing reducer tests are regression gates, not a reason to rewrite the reducer.
Use ReScript for browser tests. Do not add JavaScript or test doubles.
Use the real component and reducer for browser assertions.
Use [the browser editor test](../libs/client/test/browser/Client__PromptEditorUpdates.test.res#L19-L63) as the mount/cleanup pattern.
Use [the handoff tests](../libs/client/test/Client__State__StateReducer.test.res#L532-L608) as the transition exemplar.
Read `AGENTS.md`, server `AGENTS.md`, and `agent_docs/elixir-style.md` before implementation.

Out of scope:

- Automatic agent selection based on message text
- Changes to Planner permissions, tool classification, or backend dispatch
- A new handoff tool, modal, or workflow
- Broad framework-prompt changes or a banner redesign

## Commands

Run development tasks through Make.
Run client build and browser targets sequentially because they share generated files.

| Purpose | Command | Expected result |
|---|---|---|
| Server prompt integration | `make -C apps/frontman_server test TEST_ARGS="test/frontman_server/agents_test.exs"` | Exit 0 |
| Existing handoff regressions | `make -C libs/client test TEST_FILTER=Client__State__StateReducer` | Exit 0 |
| New rendered banner regression | `make -C libs/client test-screenshots BROWSER_TEST_FILTER=Client__ExecutePlanBanner` | Exit 0 |
| Client lint | `make -C libs/client lint` | Exit 0 |
| Server final gate | `make -C apps/frontman_server precommit` | Exit 0 |
| Diff hygiene | `git diff --check` | Exit 0 |

Use a local test database. Do not override the test database with production connection values.
If dependencies are unavailable, report the blocker instead of substituting a fake.

## Steps

### 1. Add role-specific prompt assertions

Extend `agents_test.exs` through the existing `Agents.system_prompt` integration path.
Assert that Planner receives the handoff guidance for both WordPress and a code framework.
Assert that Executor does not receive instructions to hand its work to itself.
Retain the existing read-only policy assertions.

The guidance must communicate these facts:

- Planner prepares plans and does not perform mutations.
- Approval in a normal message does not switch agents.
- After the turn finishes, the user can select **Execute plan**.
- If that action is unavailable, the user can select Executor in the agent selector.
- The agent cannot invoke the button or grant itself write access.
- Framework mutation instructions describe later Executor work.
- Planner must not report expected permission filtering as missing implementation functionality.

Verify: run the server prompt command. New assertions must fail before the guidance exists.

### 2. Add one source of handoff guidance

Match the agent's semantic `name` in `SystemPrompt.compose`.
Do not match an agent UUID, model name, or display color.
Append a small Planner-only guidance section using the existing section composition pattern.
Keep the section deterministic and inside the existing prompt-cache structure.
Update the contradictory configuration sentence without duplicating the detailed guidance.

Verify: run the server prompt command. All tests must pass.

### 3. Explain the distinction beside the existing action

Keep the button label **Execute plan**.
Replace its helper text with a concise explanation:

> Switches to Executor to make changes. Approval text does not switch agents.

The banner can remain visible after manual agent selection.
Its explanation must not claim that every later reply uses Planner.

Do not expose the banner during a running or incomplete Planner turn.
Use the existing selector and action without changing their behavior.

Add a real Chromium component test.
Assert the visible explanation and accessible button name.
Connect the click to the actual reducer with a completed Planner state.
Assert one Executor submission and no second submission after another click.
The test must inspect real reducer output, not a mocked dispatch implementation.

Verify: run the browser command and existing handoff regressions.

### 4. Finish the change

Run the remaining gates in the command table.
Add a changeset for the user-visible guidance.
Record results and any blocked gates in the implementation summary.

## Done criteria

- [ ] Planner guidance names the existing action and preserves read-only access.
- [ ] Ordinary approval text still does not switch agents.
- [ ] The rendered banner explains the agent switch.
- [ ] Browser click integration produces exactly one Executor submission.
- [ ] Prompt, reducer, browser, lint, and server gates pass.
- [ ] No out-of-scope file changes exist.

## STOP conditions

- The live product no longer has an Executor selector or an **Execute plan** action.
- The semantic agent names differ from the current code.
- Implementation requires a new server API, permission escalation, or a new model call.
- A required dependency is unavailable.
- A gate fails twice after a reasonable correction.

## Git workflow and maintenance

Use a focused feature branch or an attached isolated Delta worktree.
Keep the change below the root guideline of 500 net-new lines.
Do not merge, push, deploy, or publish without explicit authorization.
Review the prompt wording whenever the handoff button or agent names change.
