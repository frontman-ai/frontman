---
title: Use Frontman Plans & Todo Lists
description: Follow, redirect, and understand the task plan Frontman maintains while completing multi-step work.
---

For complex tasks, Frontman can create a visible todo list that tracks completed, active, and pending work. The list is an execution aid maintained by the agent, not a promise that every initial step will remain unchanged.

## When plans are created

Frontman's `todo_write` tool instructs the agent to create a plan for tasks with **three or more distinct steps that benefit from tracking**. Simple, single-step tasks such as fixing a typo do not need one. The selected model still decides when to call the tool.

Examples of tasks that trigger a plan:

- Refactoring a component and updating its tests
- Building a new page with multiple sections
- Fixing a bug that spans several files

## How plans appear

Plans are rendered directly in the chat UI as a checklist. Each item shows:

- **Content** — what the step is (e.g., "Fix authentication bug")
- **Active form** — what's shown while it's running (e.g., "Fixing authentication bug")
- **Status** — `pending`, `in_progress`, or `completed`
- **Priority** — `high`, `medium` (default), or `low`

The agent's tool instructions say to keep exactly one item `in_progress` while work is underway. The chat renders status icons and completed-item progress; you can expand or collapse a plan without changing its contents.

## Complete example

Suppose you ask:

```text
Add an empty state to the orders page, update its test, and verify the page in the browser.
```

Frontman can create this initial plan:

| Item                                      | Status        | Priority |
| ----------------------------------------- | ------------- | -------- |
| Inspect the orders page and existing test | `in_progress` | `high`   |
| Implement the empty state                 | `pending`     | `high`   |
| Update the page test                      | `pending`     | `medium` |
| Verify the result in the browser          | `pending`     | `medium` |

After inspection, it rewrites the complete list rather than sending a one-item status patch:

| Item                                      | Status        |
| ----------------------------------------- | ------------- |
| Inspect the orders page and existing test | `completed`   |
| Implement the empty state                 | `in_progress` |
| Update the page test                      | `pending`     |
| Verify the result in the browser          | `pending`     |

If inspection reveals that fixture data also needs an update, the agent can add that item. In this example, the final list retains the completed items and has no active item after work finishes.

## How the agent manages plans

1. **Initial plan** — The agent turns distinct work outcomes into todo items before or early in execution.
2. **Atomic updates** — Every `todo_write` call replaces the entire list. An omitted item is removed, so the agent carries completed and pending items forward when updating status.
3. **Discovery** — The agent can add newly discovered work, such as fixing a test failure caused by the requested change.
4. **Completion** — Items should move to `completed` only after their outcome is finished and relevant checks pass.

## Your control over a plan

Plans are not directly editable checklists. Control the work through chat and task controls:

- Click **Stop** if the active step is wrong or the task should not continue.
- Send a follow-up that names the outcome to skip, add, or change. The agent can rewrite the plan on its next turn.
- Narrow a large request into separate prompts when you want explicit approval between stages.
- Treat status as the agent's report. Verify important changes in files, tests, and the live preview before accepting the result.

Stopping a task stops execution; it does not itself rewrite todo statuses. A later turn can revise the plan based on your new instruction.

## Tips for working with plans

- **Check progress** — Glance at the plan to see how far along the agent is without reading every message.
- **Interrupt early** — If the active item looks wrong, stop the agent before it proceeds.
- **Reference outcomes** — In a follow-up, quote the item text and state what should change.
- **Keep verification visible** — Ask for tests or browser checks as explicit items when they matter to task completion.

## Technical details

Plans use the `todo_write` tool. [Frontman Agent Tool Capabilities](/docs/using/tool-capabilities/#todo_write) owns its parameter and status reference. [Prompt Strategies](/docs/using/prompt-strategies/) covers how to split or sequence larger requests.
