---
title: The Question Flow
description: How the Frontman agent asks you questions, how to answer, and what happens when you decline.
---

Most of the time, the Frontman agent works autonomously — it reads your prompt, looks at the page, edits code, and verifies the result. But sometimes it doesn't have enough information to proceed confidently. When that happens, it uses the **question tool** to pause the agent loop and ask you directly.

This page explains why the question tool exists, how it works under the hood, how you interact with it, and what happens in edge cases.

## Why the question tool exists

AI agents that guess when they're unsure produce worse results. The question tool gives the agent a structured way to ask for your input rather than making an arbitrary choice. It's used in four situations:

1. **Offering a choice between approaches** — "Should I fix this with flexbox or grid?" or "Do you want a modal or an inline expansion?"
2. **Clarifying ambiguous requests** — "You said 'make it smaller' — do you mean the font size, the padding, or the whole section?"
3. **Asking for approval** — "This will delete the `Header` component and replace all 12 usages. Proceed?"
4. **Requesting values** — "What should the max-width breakpoint be?" or "What's the API endpoint URL?"

The key design principle: **the agent loop fully stops** while a question is pending. No LLM calls, no tool executions, no token burn. The loop only resumes when you respond.

## How it works

### The tool call

When the agent decides it needs input, it calls the `question` tool with a structured payload:

| Parameter | Type | Description |
|-----------|------|-------------|
| `questions` | array | One or more question objects (see below) |

Each question object contains:

| Field | Type | Description |
|-------|------|-------------|
| `question` | string | The question text shown to you |
| `header` | string | A short label for the question (shown in the drawer header and stepper dots) |
| `options` | array | Predefined choices, each with a `label` and `description` |
| `multiple` | boolean? | If `true`, you can select more than one option. Default: `false` |

### The blocking promise

Under the hood, the question tool is an **interactive MCP tool**. When it executes, it creates a JavaScript Promise that blocks until you respond. The server-side agent loop waits on this tool result — no further LLM calls happen while the promise is unresolved.

This is fundamentally different from regular tools like `take_screenshot` or `read_file`, which resolve immediately. The question tool holds the entire agent pipeline in a paused state.

### The interactive drawer

When a question arrives, a drawer slides up from the bottom of the chat panel. It covers the message list and input area but leaves the task tabs accessible — you can switch tasks while a question is pending.

The drawer shows:

- **Header** — "Question from agent" with the question's header label
- **Question text** — the full question the agent is asking
- **Option buttons** — the predefined choices with labels and descriptions
- **Custom text input** — a textarea below the options for typing a freeform answer
- **Navigation controls** — Back, Skip, Next/Submit buttons, and stepper dots for multi-question flows

## Answering questions

### Selecting options

Click an option to select it. The behavior depends on the `multiple` setting:

- **Single-select** (default) — clicking an option selects it and deselects any previous selection. Clicking the selected option again deselects it.
- **Multi-select** — clicking toggles each option independently. You can select as many as you want.

Selected options show a purple highlight with a checkmark indicator. Single-select options show a radio-style dot; multi-select options show a checkbox.

### Typing a custom answer

Below the options, there's always a "or type your own" textarea. Typing in it switches the answer mode from option-selection to custom text. If you then click a predefined option, it switches back to option-selection mode and clears the custom text.

Custom text answers are sent to the agent as a single-element array, just like selecting one option. The agent sees the text you typed as the answer.

### Multi-question navigation

The agent can ask multiple questions in a single tool call. When it does, the drawer shows stepper dots in the footer — one dot per question. You navigate between questions using:

- **Next** button — advances to the next question (becomes "Submit" on the last question)
- **Back** button — returns to the previous question
- **Stepper dots** — click any dot to jump directly to that question

Each dot indicates its status:
- **Active** (current question) — filled purple with a ring
- **Answered** — filled purple
- **Skipped** — outlined purple
- **Unanswered** — gray

You can answer questions in any order and revisit previous answers before submitting.

### Submitting

Click **Submit** (shown on the last question when you have an answer) to send all your answers back to the agent. The drawer closes, the question tool resolves, and the agent loop resumes with your answers.

The agent receives a structured response:

```json
{
  "answers": [
    { "question": "Should I use flexbox or grid?", "answer": ["flexbox"] },
    { "question": "What max-width?", "answer": ["1200px"] }
  ],
  "skippedAll": false,
  "cancelled": false
}
```

Each answer is an array of strings — option labels for selections, or your typed text for custom answers. Skipped questions have no `answer` field.

## Skipping and cancelling

You have three ways to decline answering:

### Skip (per question)

Click the **Skip** button to skip the current question and advance to the next one. The agent sees that question's answer as missing (no `answer` field in the response). On the last question, skipping auto-submits the entire response.

This is useful when only some questions are relevant — you can answer the ones you care about and skip the rest.

### Skip all (decide for me)

Click **"Skip all (decide for me)"** in the footer to skip every question at once. The drawer closes and the agent receives:

```json
{
  "answers": [...],
  "skippedAll": true,
  "cancelled": false
}
```

The `skippedAll: true` flag tells the agent you want it to make all the decisions itself. The agent will proceed using its best judgment.

### Cancel (stop agent)

Click **"Cancel (stop agent)"** in the footer to reject the question entirely and stop the agent loop. This is a hard stop — the agent's tool promise is rejected with a "Cancelled by user" error, and the agent turn is cancelled.

Use this when you realize the agent is heading in the wrong direction and you want to start over with a new prompt.

## What the agent sees in chat

After a question tool call completes, a compact summary card appears in the chat history:

- **While waiting** — a purple shimmer card showing "Asking a question..." with the question headers listed
- **After answering** — a purple card showing "User responded" with each question and its answer (or "skipped")
- **After skipping all** — a purple card showing "Skipped (decide for me)"
- **After cancelling** — a red card showing "Cancelled by user"

These cards are part of the conversation history and persist across page refreshes and reconnections.

## Reconnection resilience

If you disconnect (close the browser tab, lose network, refresh the page) while a question is pending, Frontman handles it gracefully:

1. On reconnect, the server re-sends the unresolved tool call via MCP
2. The client receives the pending question and re-opens the drawer
3. You can answer as if nothing happened — the agent resumes from where it left off

The question state (which options you'd selected, any custom text you'd typed) is reset on reconnect since it's stored in browser memory.

:::tip
Questions survive reconnections, but your in-progress selections don't. If you'd partially answered a multi-question flow before disconnecting, you'll need to re-answer from scratch when you reconnect.
:::

## How it affects your workflow

### The agent is instructed to use questions sparingly

The agent's system prompt tells it to be proactive — to do the work rather than asking. It's only instructed to use the question tool when:

- The request is ambiguous in a way that would produce **materially different results**
- The action is **destructive or irreversible**
- It needs a **credential or value** that can't be inferred from context

This means you shouldn't see questions for routine decisions. If the agent is asking too many questions, try being more specific in your prompts.

### Questions don't count toward your usage

While a question is pending, the agent loop is fully paused. No LLM calls are made, so no tokens are consumed. You can take as long as you want to answer — there's no timeout on your end.

:::note
The server has a safety-net timeout for the blocking tool call, but it's designed to be long enough that it never triggers during normal use. It exists to prevent orphaned agent processes, not to rush you.
:::

### You can switch tasks while a question is pending

The question drawer only appears for the active task. If you switch to a different task tab, the drawer hides. Switch back and it reappears with your selections intact. The agent for the other task continues to be paused — switching tabs doesn't cancel the question.

## Technical reference

For the full tool parameter reference, see the [`question` entry in Tool Capabilities](/docs/using/tool-capabilities/#question).

### Input schema

```json
{
  "questions": [
    {
      "question": "What layout approach should I use for the card grid?",
      "header": "Layout approach",
      "options": [
        {
          "label": "CSS Grid",
          "description": "Native grid layout with auto-fill and minmax for responsive columns"
        },
        {
          "label": "Flexbox",
          "description": "Flex-wrap with percentage widths, more browser support"
        }
      ],
      "multiple": false
    }
  ]
}
```

### Output schema

```json
{
  "answers": [
    {
      "question": "What layout approach should I use for the card grid?",
      "answer": ["CSS Grid"]
    }
  ],
  "skippedAll": false,
  "cancelled": false
}
```

| Field | Type | Description |
|-------|------|-------------|
| `answers` | array | One entry per question. Each has `question` (string) and optionally `answer` (string array). |
| `answers[].answer` | string[]? | The selected option labels or custom text. Missing if the question was skipped. |
| `skippedAll` | boolean | `true` if the user clicked "Skip all (decide for me)" |
| `cancelled` | boolean | `true` if the user clicked "Cancel (stop agent)" |
