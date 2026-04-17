---
title: Architecture Overview
description: How Frontman works under the hood — the agent loop, client-server-LLM flow, ACP/MCP protocols, and tool routing.
---

Frontman is a browser-based coding agent built as a distributed system. A single prompt can move through four environments during one turn:

1. **The browser client** renders the chat UI, hosts the live preview iframe, and executes browser-side tools described in [Tool Capabilities](/docs/using/tool-capabilities/).
2. **The Frontman server** orchestrates the agent loop, manages sessions, persists interactions, and routes tool calls.
3. **The LLM provider** generates responses and decides when to call tools.
4. **Your dev server** executes file and project-structure tools on the machine that owns the source code through the relevant [framework integration](/docs/reference/compatibility/).

This page describes how those parts fit together and how data moves between them.

## System purpose

Frontman lets an LLM act on a real running application instead of operating only on text. The agent can inspect the rendered DOM, take screenshots, read source files, edit code, and verify the result against the live preview.

The design constraint is deliberate: the Frontman server does **not** require direct access to your filesystem or browser. Browser inspection happens in the browser. File operations happen on your machine through the framework integration. The server coordinates the loop and persists the state discussed in [Persistence model](#persistence-model).

## High-level architecture

```text
┌───────────────┐      WebSocket / ACP / MCP      ┌──────────────────┐
│ Browser       │ ◄──────────────────────────────► │ Frontman Server  │
│ - Chat UI     │                                  │ - Agent runtime  │
│ - Live preview│                                  │ - Persistence    │
│ - Browser tools                                  │ - Tool routing   │
└──────┬────────┘                                  └────────┬─────────┘
       │                                                      │
       │ HTTP relay for file tools                            │ API call
       ▼                                                      ▼
┌──────────────────┐                                 ┌──────────────────┐
│ Dev Server       │                                 │ LLM Provider     │
│ - File reads     │                                 │ - Response text  │
│ - File edits     │                                 │ - Tool calls     │
│ - Project info   │                                 │ - Turn complete  │
└──────────────────┘                                 └──────────────────┘
```

## Core runtime flow

A prompt runs through a repeatable loop:

1. The user sends a prompt from the browser.
2. The server resolves the model and API key to use as described in [Models & Providers](/docs/reference/models/) and [API Keys & Providers](/docs/api-keys/).
3. The server constructs the agent context: system instructions, history, tool definitions, and task state.
4. The runtime submits that context to the LLM provider.
5. The LLM either returns assistant text or requests one or more tool calls.
6. The server executes server-side tools directly and relays browser or filesystem tools through the client.
7. Tool results are fed back into the runtime.
8. The loop continues until the LLM returns `turn_complete`.

In practice, one user-visible response is usually a sequence of smaller steps: inspect, locate, edit, verify, report. The user-facing version of this flow is covered in [How the Agent Works](/docs/using/how-the-agent-works/).

## End-to-end execution sequence

```text
Client                          Server                          LLM Provider
  │                               │                               │
  │── prompt (ACP over WS) ─────►│                               │
  │                               │── build context ─────────────►│
  │                               │◄── response + tool calls ─────│
  │                               │                               │
  │◄── MCP tool call─────────────│                               │
  │── execute browser tool        │                               │
  │   or relay file tool          │                               │
  │── tool result ───────────────►│── feed result to runtime ───►│
  │                               │◄── next response / complete ──│
  │◄── streamed events───────────│                               │
```

The same control path applies whether the tool is a screenshot, a DOM read, or a file edit. What changes is where the tool runs.

## Tool execution model

Frontman splits tools by execution environment, which complements the user-facing tool overview in [Tool Capabilities](/docs/using/tool-capabilities/).

| Tool category | Runs where | Examples | Why |
| --- | --- | --- | --- |
| Browser tools | Browser client, against the preview iframe | `take_screenshot`, `get_dom`, `search_text`, `interact_with_element`, `set_device_mode` | Only the browser has direct access to the rendered page state |
| Dev server tools | Your local framework integration | `read_file`, `write_file`, `edit_file`, `grep`, `list_tree` | Source files live on your machine, not on the Frontman server |
| Server tools | Frontman server process | `todo_write`, `web_fetch` | These operate on server-side state or external network access |

### File tool relay

File tools do not execute on the Frontman server. They relay through the browser to the dev server that is running your application.

```text
Agent runtime ──MCP tool call──► Browser client ──HTTP──► Dev server plugin
Agent runtime ◄─MCP tool result── Browser client ◄─────── Dev server plugin
```

This has a few direct consequences:

- File tools require an active browser session.
- The framework integration performs the actual filesystem I/O.
- The server remains isolated from the local project filesystem.

That boundary is one of the main security and deployment properties of the system. For deployment implications, see [Self-Hosting](/docs/reference/self-hosting/).

## Persistence model

Frontman persists agent activity as typed interactions in PostgreSQL before broadcasting them to connected clients.

This persist-then-broadcast model matters for reliability:

- If the browser disconnects, interaction history is not lost.
- Reconnecting clients can reconstruct the full task state from the database.
- The runtime can replay prior interaction history back into LLM message format when resuming work.

The server stores domain events such as user messages, agent responses, tool calls, tool results, pauses, retries, and completion markers as structured JSONB records. The UI is therefore rendering persisted task history, not a transient in-memory transcript.

## Server architecture

The Phoenix application is responsible for orchestration, persistence, session management, and channel transport.

### Main responsibilities

- Accept ACP and MCP messages over WebSocket channels.
- Resolve model/provider credentials.
- Build agent execution context.
- Submit work to the `SwarmAi.Runtime`.
- Route tool calls to the correct execution environment.
- Persist interactions and broadcast updates.
- Expose authenticated HTTP endpoints for settings, OAuth, and token exchange.

### Major server components

| Component | Responsibility |
| --- | --- |
| `SwarmAi.Runtime` | Runs the agent loop and coordinates LLM interactions |
| `TaskChannel` | Handles per-task prompt traffic, tool routing, and streamed updates |
| `TasksChannel` | Handles task listing, creation, deletion, and session initialization |
| `ToolCallRegistry` | Tracks pending client-executed tool calls and resolves waiting processes |
| `SwarmDispatcher` | Persists interactions and broadcasts them through PubSub |
| `Providers` | Resolves API keys, OAuth tokens, usage limits, and model catalog data |
| `Repo` | Stores tasks, interactions, credentials, identities, and organizations |

### Session and transport layer

The wire protocol uses JSON-RPC 2.0 messages over Phoenix channels.

- **ACP** handles session lifecycle and prompt exchange.
- **MCP** handles tool registration, tool calls, and tool results.

The split is intentional: ACP describes the conversation and task lifecycle, while MCP describes executable capabilities exposed to the agent. Configuration and deployment details that affect this transport layer are documented in [Configuration Options](/docs/reference/configuration/) and [Environment Variables](/docs/reference/env-vars/).

## Client architecture

The browser client has two jobs at the same time:

1. Present the task UI to the user.
2. Act as an execution host for browser tools and a relay for dev-server tools.

For the user-facing side of this behavior, see [How the Agent Works](/docs/using/how-the-agent-works/), [Web Preview](/docs/using/web-preview/), and [The Question Flow](/docs/using/question-flow/).

### Main client responsibilities

- Render the chat transcript, plans, tool activity, and question UI.
- Host the preview iframe used for DOM inspection and screenshots.
- Maintain the WebSocket connection to the server.
- Register browser-side MCP tools.
- Relay file and project-inspection requests to the local dev server.

### State model

The client is built around a reducer-driven external store implemented in `libs/react-statestore`. Public reads go through selectors, and actions dispatch state transitions plus side effects.

That split keeps the UI reactive while preserving a single state transition path for streamed updates, tool calls, questions, and task lifecycle events.

## Protocol stack

Frontman uses three layers that build on each other:

1. **JSON-RPC 2.0** for the message envelope.
2. **ACP** for task and session semantics.
3. **MCP** for tool discovery and tool execution.

A typical prompt therefore uses ACP for the user message, MCP for any tool calls generated during the turn, and JSON-RPC as the transport envelope for both.

## Framework integrations

The local dev server integration is how Frontman gains project awareness and filesystem access.

Published integrations exist for Astro, Next.js, and Vite. Each integration injects the Frontman client into the running application, exposes HTTP endpoints or middleware for file tools, and provides framework-specific metadata where available.

Examples:

- **Astro** can expose source file annotations and dev-toolbar context.
- **Next.js** can capture logs and instrument request flow.
- **Vite** can adapt the same tool surface across multiple frontend frameworks.

The integration layer is the bridge between the generic agent runtime and the specifics of an application's build system and file layout. See [Supported Frameworks](/docs/reference/compatibility/) for version support and [Configuration Options](/docs/reference/configuration/) for integration settings.

## Reliability and failure handling

Several architectural choices are there to keep task state coherent when things go wrong:

- Interactions are persisted before broadcast.
- Pending client-side tool calls are tracked in a registry rather than assumed to complete immediately.
- Interactive tools can pause the agent instead of forcing a hard failure.
- Reconnected clients can reload state from persisted interactions.

This does not eliminate failure modes, but it prevents common ones from corrupting task history or silently dropping work.

## Operational boundaries

When debugging or extending Frontman, these boundaries matter most:

1. **Browser boundary** — anything that needs the live DOM or visual output must run in the browser.
2. **Filesystem boundary** — anything that touches project files must go through the local framework integration.
3. **Server boundary** — orchestration, persistence, authentication, and runtime coordination stay on the server.
4. **Provider boundary** — model behavior and tool selection originate with the external LLM provider.

If a feature crosses one of those boundaries, the implementation usually needs explicit protocol support rather than a local-only change.

## Monorepo layout

The repository is organized as a monorepo with separate applications and shared libraries.

- `apps/frontman_server/` contains the Phoenix backend.
- `apps/marketing/` contains the Astro documentation and marketing site.
- `apps/swarm_ai/` contains the runtime package used for agent execution.
- `libs/client/` contains the ReScript React client.
- `libs/frontman-core/` contains shared tool definitions and filesystem tool implementations.
- `libs/frontman-protocol/` contains ACP/MCP types and schemas.
- `libs/frontman-astro/`, `libs/frontman-nextjs/`, and `libs/frontman-vite/` contain framework integrations.

This split keeps protocol types, client logic, runtime behavior, framework adapters, and the server deployable as separate units while still sharing a single source tree.

## Related documentation

- [How the Agent Works](/docs/using/how-the-agent-works/) for the user-facing explanation of the same loop.
- [Tool Capabilities](/docs/using/tool-capabilities/) for the available tool surface.
- [Configuration Options](/docs/reference/configuration/) for integration and runtime settings.
- [Self-Hosting](/docs/reference/self-hosting/) for deployment architecture.
