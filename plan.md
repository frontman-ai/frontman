# Agent Awareness and Switch Actions

## Goal

Make every configured agent aware of the other available agents and allow agents to recommend switching to another agent through a structured action rendered as a button.

Clicking a recommendation button selects the target agent and prefills a suggested handoff prompt. It never submits automatically. If the composer already contains a draft, Frontman asks for confirmation before replacing it.

## Implementation Plan

### 1. Add agent awareness to system prompts

- Change `Agents.system_prompt/2` to receive the current scope or resolved agent catalog.
- Add an `Available Agents` section in `apps/frontman_server/lib/frontman_server/agents/system_prompt.ex`.
- Include each agent's stable ID, display name, and description.
- Clearly identify the agent handling the current turn.
- Explain that agents share the current session history and may recommend another agent when that agent is better suited to continue.
- Do not expose other agents' private system prompts.
- Tell agents that a recommendation affects a future user prompt and does not switch the current turn.
- Keep recommendation guidance conditional on the recommendation tool being available, so older clients remain compatible.

### 2. Add a structured `recommend_agent` browser tool

- Add `recommendAgent` to `FrontmanProtocol__Tool.ToolNames`.
- Create `libs/client/src/tools/Client__Tool__RecommendAgent.res`.
- Register the tool in `Client__ToolRegistry.res`.
- Make the tool synchronous, read-access, and visible to agents so both Planner and Executor can use it.
- Define the input and output with Sury schemas.

The structured input should contain:

```rescript
{
  targetAgentId: string,
  reason: string,
  suggestedPrompt: string,
}
```

- Validate that `targetAgentId` exists in the negotiated client agent catalog.
- Require non-empty `reason` and `suggestedPrompt` values and apply reasonable length limits.
- Return catalog validation failures as normal MCP tool errors.
- Do not change the selected agent while executing the tool. The tool records a recommendation; the user chooses whether to accept it.
- Derive target display name, description, and color from the negotiated catalog rather than accepting presentation metadata from the model.

### 3. Render recommendations as specialized tool cards

- Add `Client__AgentRecommendationToolBlock.res`.
- Route `recommend_agent` calls to it from `Client__ToolCallBlock.res`, following the existing specialized question-tool rendering pattern.
- Parse the tool input with the same Sury schema used by the tool.
- Show the recommending agent's reason and the catalog-owned target identity.
- Render a button such as `Continue with Executor`.
- Show a non-actionable loading state until the recommendation input is complete and validated.
- If the target no longer exists in the current catalog, preserve the historical card but show `Agent unavailable` and disable the button.
- Keep historical and replayed recommendation cards actionable while their target remains available.

### 4. Implement select-and-prefill behavior

- Handle recommendation acceptance in `Client__Chatbox.res`, where both message actions and the composer are available.
- On acceptance, select the target with `Client__State.Actions.setSelectedAgentId`.
- Pass a uniquely identified prefill request through `Client__PromptInput.res` to `Client__PromptEditor.res`.
- Add the minimal typed Tiptap binding needed to replace editor content.
- Insert `suggestedPrompt` and focus the editor.
- Do not submit the prompt or start the recommended agent automatically.

When the composer is empty:

1. Select the target agent.
2. Insert the suggested prompt.
3. Focus the composer for review.

When the composer contains text or attachments:

1. Open `Client__UI__AlertDialog` explaining that the current draft will be replaced.
2. On confirmation, select the target agent and replace the draft with the suggested prompt.
3. On cancellation, preserve both the current draft and the current agent selection.

### 5. Add recommendation guidance for agents

- Recommend another agent only when it is materially better suited for the next step.
- Use the exact target ID from the available-agent catalog.
- Explain why switching helps.
- Supply a concrete handoff prompt with enough context for the target agent to continue using the shared session history.
- Do not recommend the current agent.
- Do not claim that invoking `recommend_agent` switched the current turn.
- Do not emit a recommendation when continuing with the current agent is sufficient.

### 6. Preserve the existing protocol and persistence model

- Represent recommendations through ordinary tool calls and tool results.
- Reuse existing MCP discovery, ACP tool-call updates, interaction persistence, and history replay.
- Do not introduce a custom ACP session update or content-block variant.
- Do not add a new interaction type or database migration.
- Older clients will simply not advertise `recommend_agent`; the server and agents must continue to operate without it.

### 7. Add tests

Server prompt tests:

- The catalog section includes every configured agent.
- Stable IDs, display names, and descriptions are present.
- The current agent is identified correctly.
- Configured ordering is preserved.
- A one-agent catalog does not encourage switching.
- Existing agent-specific system prompts and tool policies remain intact.

Client tool tests:

- A valid target returns structured JSON.
- An unknown target returns an MCP error.
- Empty or malformed fields fail schema validation.
- Executing the tool does not alter agent selection or submit a prompt.
- The tool is synchronous, visible, and read-access.

Rendering tests:

- The card uses catalog-owned target identity and color.
- The reason and action button render correctly.
- Loading, malformed, failed, and removed-target states are non-actionable.
- Replayed recommendations render the same as live recommendations.

Composer interaction tests:

- Accepting with an empty composer selects the agent and prefills the prompt.
- Prefilling focuses the editor.
- No prompt is submitted automatically.
- A non-empty composer opens a replacement confirmation dialog.
- Confirming replaces the draft and selection.
- Cancelling preserves the draft and selection.
- Existing queued prompts retain the agent selected when they were originally submitted.

### 8. Verify and document

- Run `make test` in `libs/client`.
- Run `make check` in `libs/frontman-client` if shared client bindings or behavior change.
- Run `make precommit` in `apps/frontman_server`.
- Add a changeset describing agent awareness and switch recommendation actions because this is user-visible functionality.

## Non-goals

- Agents do not autonomously invoke or start one another.
- Clicking a recommendation does not submit a prompt.
- This does not add direct agent-to-agent transport separate from shared session history.
- This does not introduce durable plan-item tracking.
- This does not change the agent assigned to a running or already queued turn.
- This does not create a generic action framework before another concrete action requires it. Additional actions can use their own typed tools and specialized renderers.

## Expected User Flow

1. Planner finishes inspecting the application.
2. Planner calls `recommend_agent` with Executor's ID, a reason, and a suggested implementation prompt.
3. Frontman renders a `Continue with Executor` button.
4. The user clicks it.
5. Frontman selects Executor and prefills the handoff prompt.
6. The user reviews or edits the prompt and submits it.
7. Executor receives the existing shared session history, including Planner's findings and plan.
