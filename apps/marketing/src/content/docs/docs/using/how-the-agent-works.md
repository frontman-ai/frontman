---
title: How the Agent Works
description: Understand the Frontman agent loop — how it sees your page, reads your code, and makes changes.
---

Frontman is an AI agent that sits between your browser and your source code. You describe a change in natural language, and it executes that change by looking at your running app, reading relevant files, and editing them — all without you leaving the browser.

This page explains what happens under the hood so you can work with the agent more effectively.

## The three-part system

Frontman has three main components:

1. **The browser client** — a chat interface that sits alongside a live preview of your app. It also runs browser-side tools (screenshots, DOM inspection, clicking elements).

2. **The Frontman server** — receives your prompts, calls the LLM (Claude, GPT, Gemini, etc.), and orchestrates the agent loop.

3. **Your dev server plugin** — a framework integration (Astro, Next.js, or Vite) that gives the agent access to your project files and component structure.

```
┌─────────────────────────────────────────────┐
│  Your Browser                               │
│  ┌────────────┐  ┌────────────────────┐     │
│  │  Chat UI   │  │  Live Preview      │     │
│  │            │  │  (your running app)│     │
│  └──────┬─────┘  └──────────┬─────────┘     │
└─────────┼───────────────────┼───────────────┘
          │                   │
          ▼                   ▼
┌──────────────────┐ ┌──────────────────┐
│ Frontman Server  │ │ Your Dev Server  │
│ (agent loop,     │ │ (file tools,     │
│  LLM calls)      │ │  project info)   │
└────────┬─────────┘ └──────────────────┘
         │
         ▼
┌──────────────────┐
│  LLM Provider    │
│  (Claude, GPT,   │
│   Gemini, etc.)  │
└──────────────────┘
```

## What happens when you send a prompt

### 1. Your message reaches the server

When you type a message and hit send, the client packages it — text, images, and any [annotations](/docs/using/annotations/) you've added — and sends it to the Frontman server over a WebSocket connection.

### 2. The server picks an LLM

The server resolves which AI model and API key to use, checking in this order:

1. **OAuth connection** — if you've linked your Anthropic or OpenAI account directly
2. **Your API key** — a key you've saved in Frontman settings
3. **Environment key** — a key from your project's `.env` file
4. **Free tier** — Frontman's built-in key (limited to 10 runs/day)

See [API Keys & Providers](/docs/api-keys/) for setup details.

### 3. The agent loop starts

The server builds a context package — system prompt, available tools, conversation history — and submits it to the LLM. This begins the **agent loop**: a back-and-forth between the LLM and your browser that continues until the task is done.

### 4. The LLM decides what to do

On each turn, the LLM either:

- **Returns text** — streamed to your chat in real time as it's generated
- **Calls tools** — requests actions like "take a screenshot" or "read this file"

### 5. Tools execute where they need to

Tools run in different places depending on what they do:

| Tool type | Where it runs | Examples |
|-----------|---------------|----------|
| **Browser tools** | In your browser, against the live preview | Screenshot, DOM inspection, clicking elements, navigating |
| **Dev server tools** | On your dev server, via the framework plugin | Reading files, editing code, discovering project structure |
| **Server tools** | On the Frontman server | Todo list management, plan tracking |

The results are sent back to the LLM, which uses them to decide its next action.

### 6. The loop repeats until done

Steps 4–5 repeat until the LLM determines the task is complete. A typical flow looks like this:

1. Take a screenshot to see the current state
2. Read the DOM to understand the page structure
3. Read the relevant source file
4. Edit the file
5. Take another screenshot to verify the change
6. Report back to you

The agent might loop 3–15 times depending on complexity. Simple text changes might take 3 steps. A multi-component layout rework might take 15.

:::tip
Every interaction is saved to a database, so your conversation survives page refreshes and reconnections. You can close your browser and come back later — the full history will be there.
:::

## The screenshot → read → edit cycle

The agent's core workflow is a perception-action loop:

1. **See** — take a screenshot of the live preview to understand the visual state
2. **Understand** — inspect the DOM, find interactive elements, or search for text to map what's visible to underlying structure
3. **Locate** — identify the source file and line responsible for what needs to change
4. **Edit** — modify the code with a targeted diff
5. **Verify** — take another screenshot to confirm the change looks right

This is why Frontman can make precise visual changes that other AI coding tools struggle with — it has the same feedback loop a human developer uses: look at the page, find the code, change it, check the result.

## How tools get routed

When the LLM requests a tool that runs in the browser (like a screenshot), the server sends the request to your browser over the WebSocket. The browser executes it against the live preview iframe and returns the result.

For tools that need your dev server (like editing a file), the browser acts as a bridge — it receives the request from the server, forwards it to your dev server's Frontman plugin over HTTP, and returns the result.

```
Agent → Server → Browser → Dev Server → Browser → Server → Agent
```

This relay architecture means the agent can access your files without the Frontman server needing direct access to your filesystem. Your code stays on your machine.

## What the agent can see

The agent has access to a rich set of tools. Here's a summary — see [Tool Capabilities](/docs/using/tool-capabilities/) for the full reference.

| Capability | What the agent gets |
|-----------|-------------------|
| **Screenshots** | A pixel-accurate capture of your running app |
| **DOM tree** | A structured representation of the page with CSS selectors, component names, and text content |
| **Interactive elements** | All buttons, links, inputs, and other clickable elements with their ARIA roles and names |
| **Text search** | Find any visible text on the page |
| **File reading** | Read source files with line numbers |
| **File editing** | Make targeted edits using fuzzy text matching |
| **Navigation** | Change the URL in the preview |
| **Device emulation** | Switch between desktop, tablet, and mobile viewports |
| **Questions** | Pause and ask you for clarification when it's unsure |

## The Question flow

Sometimes the agent needs more information before proceeding. When this happens, it uses the **Question** tool to pause the loop and show you a UI drawer with the question and suggested options.

The agent loop is literally paused — no LLM calls happen until you respond. Once you answer, your response is fed back to the LLM and the loop continues.

See [The Question Flow](/docs/using/question-flow/) for more detail.

## Plans and todo lists

For complex tasks, the agent creates a structured plan — a list of steps with statuses (pending, in progress, completed). This plan is visible in the chat UI so you can track progress.

The agent updates the plan as it works, marking items complete and adding new ones as it discovers subtasks. See [Plans & Todo Lists](/docs/using/plans-and-todos/).

## Next steps

- **[Sending Prompts](/docs/using/sending-prompts/)** — how to write prompts that get good results
- **[Annotations](/docs/using/annotations/)** — point at elements instead of describing them
- **[Tool Capabilities](/docs/using/tool-capabilities/)** — full reference for every tool
- **[Architecture Overview](/docs/reference/architecture/)** — the full technical deep-dive
