---
title: 'Agent Client Protocol: Building an Agentic Harness'
seoTitle: 'Agent Client Protocol: Building an Agentic Harness'
pubDate: 2026-06-28T18:00:00Z
description: 'How Frontman uses Agent Client Protocol to connect browser UI, agent sessions, streaming updates, and tool calls in an agentic harness.'
author: 'Danni Friedland'
authorRole: 'Co-founder, Frontman'
image: '/blog/agent-client-protocol-agentic-harness-cover.png'
imageWidth: 1200
imageHeight: 450
imageAlt: 'Agent Client Protocol cover showing Frontman agentic harness architecture'
tags: ['ai', 'developer-tools', 'agent-protocols']
faq:
  - question: 'What is Agent Client Protocol?'
    answer: 'Agent Client Protocol is an open protocol for communication between coding agents and clients such as editors, IDEs, or browser-based developer interfaces. Frontman uses it for session lifecycle, prompts, streaming updates, cancellation, and task history.'
  - question: 'How does Frontman use ACP?'
    answer: 'Frontman sends ACP-shaped JSON-RPC messages over Phoenix WebSocket channels. ACP handles initialize, session creation, session loading, prompt submission, streamed session updates, and cancellation.'
  - question: 'Is ACP the same as MCP?'
    answer: 'No. ACP describes the conversation and session between client and agent. MCP describes tool discovery, tool calls, and tool results. Frontman uses both, with JSON-RPC as the message envelope.'
  - question: 'Is Frontman a pure ACP implementation?'
    answer: 'Frontman is ACP-aligned for core agent-client session semantics, but it also uses Phoenix channel transport and a few Frontman-specific events for product concerns like title updates, configuration updates, and retry.'
---

You start with a chat box. Then the agent needs to stream output. Then it needs to show tool calls. Then it needs to cancel a run. Then the browser disconnects and reconnects. Then someone asks why the plan disappeared after refresh.

This is where most agent products quietly become a pile of bespoke socket events.

`message:start`. `message:delta`. `tool:started`. `tool:done`. `session:restore`. `run:cancelled`. A dozen events, each with slightly different casing, slightly different error handling, and one optimistic assumption that only fails in production.

Frontman avoids that by treating the browser UI, the agent server, and the running development environment as an **agentic harness**. The harness needs a protocol, not vibes. For Frontman's client-to-agent layer, that protocol is [Agent Client Protocol](https://agentclientprotocol.com/get-started/introduction).

This post is the first in a series on building an agentic harness. We are starting with ACP because session semantics are the foundation. If the client and agent cannot agree on what a session, prompt, update, tool call, cancellation, and replay mean, the rest of the system becomes archaeology.

### What Frontman Is

Frontman is an open-source browser-based AI coding agent for frontend work. It runs inside your app at `/frontman`, shows chat beside a live preview, lets a user click a UI element, describe a change, and then uses runtime context to edit real source files.

The important part is not the chat. The important part is what the agent can see.

Frontman can inspect the live DOM, computed CSS, screenshots, console logs, server logs, routes, build errors, component/source mappings, and project files. That makes it different from file-only coding agents. A file-only agent can read `className="p-8"`. Frontman can also see what that class actually did in the browser at the current viewport.

That architecture creates a protocol problem. The browser has the UI and runtime context. The server has the agent loop, persistence, model credentials, and LLM calls. The local dev server owns the filesystem and framework-specific project information. One prompt can move through all of them.

So Frontman is not one process. It is a small distributed system.

```text
Browser Client --ACP/MCP over WebSocket-- Frontman Server --LLM API-- Provider
     |                                             |
     +----HTTP/SSE relay---- Dev Server Tools <----+
```

That split is deliberate. The Frontman server does not need direct access to your local filesystem. Browser inspection happens in the browser. File reads and edits happen through the framework integration running with your dev server. The server coordinates the loop and persists task history.

For the longer version, the [Frontman architecture overview](/docs/reference/architecture/) covers the full client-server-LLM-tool flow.

### The Four Pieces of Frontman's Harness

Frontman has four runtime environments during a typical task.

**The browser client** renders chat, hosts the live preview iframe, maintains the WebSocket connection, and executes browser-side tools. Anything that needs the rendered page belongs here: screenshots, DOM reads, interactive element discovery, selected-element context, viewport state.

**The Frontman server** is an Elixir/Phoenix application. It manages authenticated sessions, persists interactions in PostgreSQL, builds agent context, calls the LLM provider, routes tool calls, and streams updates back to connected clients.

**The LLM provider** decides whether the next step is assistant text or a tool call. Frontman supports providers such as Anthropic, OpenAI, and OpenRouter. The model chooses actions; Frontman enforces the harness around those actions.

**The dev server integration** runs in your project through packages such as `@frontman-ai/nextjs`, `@frontman-ai/astro`, and `@frontman-ai/vite`. It exposes file tools, source resolution, project structure, and framework-specific runtime data. WordPress has its own plugin path because WordPress is its own civilization. Documentation updates do not change that.

The boundary matters. If a tool needs DOM, it runs in the browser. If a tool touches files, it goes through the local framework integration. If a feature crosses one of those boundaries, it needs protocol support. A local function call dressed as architecture will not survive reconnects, retries, or multiple clients.

### Where Agent Client Protocol Fits

The [Agent Client Protocol GitHub repository](https://github.com/agentclientprotocol/agent-client-protocol) describes ACP as a protocol for connecting any editor to any agent. Frontman uses it for the same class of problem, but our client is browser-based rather than an IDE pane.

ACP handles the relationship between client and coding agent:

- What agent implementation is this?
- What protocol version does it speak?
- What capabilities exist?
- Which session is active?
- What prompt did the user send?
- What updates should the client render?
- Why did the turn stop?
- Can this run be cancelled?

That is the conversation layer. It is not the filesystem layer. It is not the browser tool layer. It is not the LLM provider API. It is the contract that lets the client and agent agree on task state.

Frontman's shared protocol package, `libs/frontman-protocol`, defines ACP types in ReScript and exports JSON Schema artifacts. The Phoenix server validates its ACP builders against those schemas in contract tests. That sounds boring because it is supposed to be boring. Protocol bugs should fail in tests, not after a user refreshes during a tool call.

### Frontman's ACP Lifecycle

Frontman sends ACP-shaped messages as JSON-RPC 2.0 over Phoenix WebSocket channels. The browser client pushes and listens on the `acp:message` channel event. Inside that event, the payload is a normal JSON-RPC request, response, or notification.

A new connection starts with `initialize`.

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": 1,
    "clientInfo": {
      "name": "frontman-client",
      "version": "1.0.0",
      "_meta": {
        "framework": "nextjs"
      }
    },
    "clientCapabilities": {
      "fs": {
        "readTextFile": true,
        "writeTextFile": true
      },
      "terminal": false
    }
  }
}
```

The server responds with agent information and capabilities. In Frontman, those capabilities include session loading, WebSocket MCP support, image prompt support, and embedded context support.

Then the client creates or loads a session.

`session/new` creates a new task-backed ACP session. Frontman maps ACP sessions to tasks. The client generates the session ID, the server creates the task, and the result can include session configuration options such as model choices.

`session/load` hydrates an existing task. This is where ACP becomes more than a streaming format. Frontman replays persisted interactions back to the client as `session/update` notifications. User messages, agent responses, tool calls, tool results, and errors reconstruct through the same client reducer path as live updates.

That is a small design choice with large consequences: reconnect is not a separate UI model. History replay is the same protocol as live streaming.

`session/prompt` submits the user's next turn. The prompt can contain text, images, embedded resources, annotations, and current page context. The server stores the user message, builds the agent context, and starts the LLM/tool loop.

While the agent works, the server sends `session/update` notifications.

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "task-id",
    "update": {
      "sessionUpdate": "agent_message_chunk",
      "content": {
        "type": "text",
        "text": "I found the component."
      },
      "timestamp": "2026-06-28T18:00:00Z"
    }
  }
}
```

When the run ends, Frontman resolves the pending prompt with a typed `stopReason`: `end_turn`, `cancelled`, `max_tokens`, `max_turn_requests`, or `refusal`. Cancellation is also ACP-shaped: `session/cancel` is a notification, not a request. The client does not wait for a direct cancel response. The running prompt resolves when the agent reports completion with `stopReason: "cancelled"`.

### What Streams Over ACP

ACP is not just assistant text. In Frontman, `session/update` carries the visible state of the agent run.

Agent text streams as `agent_message_chunk`. User history replays as `user_message_chunk`. Tool activity appears as `tool_call` and `tool_call_update`. Plans appear as `plan` updates with complete replacement semantics. Config changes can appear as `config_option_update`. Turn completion appears as `agent_turn_complete`. Errors appear as typed error updates with metadata for retries and display.

This is what makes an ACP agent feel like an agent instead of a chatbot with a loading spinner. The user can see what the agent is doing, not just what it eventually says.

Tool calls are especially important. Frontman uses MCP for executable tools, but ACP for tool-call display. When the LLM asks to read a file, inspect the DOM, or edit a component, the UI needs a stable way to show that work. ACP gives the client a tool-call lifecycle: pending, in progress, completed, failed.

The tool result itself may travel through MCP. The user-visible status travels through ACP. Keep those separate or you will eventually invent a protocol by accident.

### Why MCP Is Separate

ACP and MCP solve adjacent problems.

ACP answers: what is happening in the agent session?

MCP answers: what tools exist, how does the agent call them, and what result came back?

Frontman uses MCP concepts for `initialize`, `tools/list`, `tools/call`, browser-side tools, and dev-server relay tools. A file edit might follow this path:

```text
Agent runtime --MCP tool call--> Browser client --HTTP/SSE--> Dev server plugin
Agent runtime <--MCP tool result-- Browser client <---------- Dev server plugin
```

ACP wraps the user-facing task state around that. It lets the browser render "editing file," "tool completed," "plan updated," and "turn complete" without caring whether the tool ran in the browser, on the dev server, or on the Frontman server.

That separation is the harness. The user sees one coherent run. The implementation respects execution boundaries.

### Schema Discipline Beats Hope

Protocol drift is not dramatic at first. It starts as a field called `sessionId` in one place and `session_id` in another. It starts as an optional content field that should have been required. It starts as one side treating `entries` as nullable while the other replaces a plan with nothing.

Then reconnect breaks. Usually in production. Usually after someone has been waiting for the agent to finish a task for five minutes.

Frontman keeps the protocol surface typed. ACP content blocks are modeled as discriminated unions: text, image, audio, resource link, embedded resource. Stop reasons are closed enums. Plan entries have required content, priority, and status. Session config options use typed categories but allow unknown categories because the ACP spec requires clients to handle them gracefully.

The ReScript protocol package exports JSON Schema files under `libs/frontman-protocol/schemas`. Server contract tests validate Phoenix ACP builders against those schema artifacts. The goal is not elegance. The goal is that the browser, server, and persisted history agree on the wire.

It cannot drift quietly because the schema is executable.

### Where Frontman Extends ACP

Frontman is ACP-aligned for core agent-client session semantics. It is not a pure reference implementation.

The transport is Phoenix Channels. ACP payloads move inside the `acp:message` channel event rather than over a raw process transport. Frontman also has product-level channel events for session listing, deletion, title updates, and config option refreshes. There is a Frontman-specific `session/retry_turn` notification because retries are part of the product's failure recovery model.

That is the honest architecture. ACP gives Frontman the session contract. Phoenix gives us authenticated WebSocket infrastructure. MCP gives us executable tool contracts. The relay protocol gets local file operations to the dev server without giving the hosted server direct filesystem access.

The important rule is to keep the seams explicit. Standard where standard fits. Extend where the product needs it. Do not pretend extensions are the standard.

### What ACP Buys Frontman

ACP gives Frontman a stable language for agent-client collaboration.

The browser can connect, initialize, create a task, load history, send a prompt, render streamed text, display tool calls, show plans, handle cancellation, and finalize turns through one protocol-shaped path. The server can persist domain interactions and replay them as ACP history. The UI can treat live updates and reconnect updates the same way.

That is what an agentic harness needs. Not more clever prompt templates. Not a larger pile of WebSocket events. A contract between the client and the agent.

The next post in this series will go one layer deeper: how Frontman routes MCP tool calls through the browser and local dev server so an agent can inspect a live app, edit source files, and verify hot reload without the hosted server owning your filesystem.

If you want to see the system from the user side first, start with [how the Frontman agent works](/docs/using/how-the-agent-works/) or try the [Frontman quickstart](/blog/getting-started/).
