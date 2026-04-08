---
title: Plans & Todo Lists
description: How Frontman uses structured plans to track progress on complex tasks.
---

For complex tasks, Frontman creates a structured plan — a visible todo list that tracks each step of the work. This gives you real-time insight into what the agent is doing, what's done, and what's next.

## When plans are created

The agent creates a plan when a task has **three or more distinct steps**. Simple, single-step tasks (like fixing a typo or answering a question) don't need one.

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

Only one item is `in_progress` at a time. As the agent finishes each step, it marks it `completed` and moves to the next.

## How the agent manages plans

1. **Upfront planning** — The agent analyzes your request and creates the full list of steps before starting work.
2. **Progressive updates** — As it works, it rewrites the list to update statuses. Each call replaces the entire list (completed items are preserved in the new list).
3. **Discovery** — If the agent discovers new subtasks while working (e.g., an unexpected test failure), it adds them to the plan.

## Tips for working with plans

- **Check progress** — Glance at the plan to see how far along the agent is without reading every message.
- **Interrupt early** — If you see a step that looks wrong, you can stop the agent before it gets further.
- **Reference steps** — You can mention specific plan items when giving follow-up instructions (e.g., "skip the test step" or "do the migration step differently").

## Technical details

Plans use the `todo_write` tool. See [Tool Capabilities](/docs/using/tool-capabilities/) for the full parameter reference.
