# How Frontman Works

Frontman is a browser-based AI agent that helps developers modify their web applications through natural language. You describe what you want changed, and Frontman executes the changes by interacting with a live preview of your app — taking screenshots, reading the DOM, clicking elements, and editing code.

This document explains how the system works, starting from the big picture and drilling into implementation details.

---

## Table of Contents

- [The Big Picture](#the-big-picture)
- [What Happens When You Send a Prompt](#what-happens-when-you-send-a-prompt)
- [The Three Protocols](#the-three-protocols)
- [Server Architecture](#server-architecture)
- [Client Architecture](#client-architecture)
- [The Agentic Loop](#the-agentic-loop)
- [Tool Execution](#tool-execution)
- [Framework Integrations](#framework-integrations)
- [Infrastructure](#infrastructure)

---

## The Big Picture

Frontman has three main parts:

1. **A browser client** (ReScript/React) that renders a chat interface alongside a live preview of your app. It also executes browser-side tools like taking screenshots and clicking elements.

2. **A server** (Elixir/Phoenix) that receives your prompts, calls an LLM (Claude, GPT, Gemini, etc.), and orchestrates the back-and-forth between the AI and your browser.

3. **Framework integrations** (Astro, Next.js, Vite plugins) that inject Frontman into your dev server so it can discover your project structure and execute code-level tools.

```
┌─────────────────────────────────────────────────────┐
│  Your Browser                                       │
│  ┌──────────────┐  ┌────────────────────────────┐   │
│  │  Chat UI     │  │  Live Preview (iframe)     │   │
│  │  - messages  │  │  - your running app        │   │
│  │  - tools     │  │  - screenshot capture      │   │
│  │  - plans     │  │  - DOM inspection          │   │
│  └──────┬───────┘  └────────────┬───────────────┘   │
│         │     WebSocket         │  HTTP/SSE          │
└─────────┼───────────────────────┼───────────────────┘
          │                       │
          ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  Frontman Server │    │  Your Dev Server │
│  (Elixir)        │    │  (Astro/Next/    │
│  - agent loop    │    │   Vite plugin)   │
│  - tool routing  │    │  - file tools    │
│  - persistence   │    │  - project info  │
└────────┬─────────┘    └──────────────────┘
         │
         ▼
┌──────────────────┐
│  LLM Provider    │
│  (Claude, GPT,   │
│   Gemini, etc.)  │
└──────────────────┘
```

---

## What Happens When You Send a Prompt

Here's the full lifecycle of a single prompt, from typing to seeing results:

### 1. You type a message and hit send

The client packages your message (text, images, or other attachments) and sends it over a WebSocket connection to the server using the ACP protocol.

### 2. The server resolves which LLM to use

The server figures out which API key and model to use based on a priority chain:

| Priority | Source | Description |
|----------|--------|-------------|
| 1st | OAuth token | If you've connected your Anthropic or OpenAI account directly |
| 2nd | Your API key | A key you've saved in your Frontman settings |
| 3rd | Environment key | A key from your project's environment (e.g., `.env`) |
| 4th | Server key | Frontman's built-in free tier (limited to 10 runs/day) |

### 3. The agent loop begins

The server builds an agent configuration (system prompt, available tools, conversation history) and submits it to the **SwarmAi Runtime** — a supervised process that manages the LLM conversation loop.

### 4. The LLM responds

The LLM either:
- **Returns text** — streamed to your browser in real-time as it's generated
- **Requests tool calls** — the server routes each tool to the right executor

### 5. Tools execute

Tools fall into two categories:

- **Browser tools** (screenshot, DOM read, click, navigate) — routed back to your browser, executed against the live preview iframe, results sent back to the server
- **Backend tools** (todo list management) — executed directly on the server

The server waits for all tool results, then feeds them back to the LLM for the next iteration.

### 6. The loop repeats

Steps 4-5 repeat until the LLM decides it's done (returns a `turn_complete` signal). Every interaction is persisted to the database, so your conversation survives page refreshes and reconnections.

---

## The Three Protocols

All communication uses **JSON-RPC 2.0** as the wire format. On top of that, two application protocols handle different concerns:

### ACP (Agent Client Protocol)

Manages the conversation lifecycle between the client and server:

- **Session management** — create, load, delete conversation sessions
- **Prompting** — send user messages, receive streamed agent responses
- **Configuration** — model selection, thinking level, config updates

Example events: `UserMessageChunk`, `AssistantMessageStart`, `ToolCallStart`, `ToolInputChunk`, `ToolCallEnd`, `TurnComplete`, `PlanEntry`.

### MCP (Model Context Protocol)

Handles tool-related communication:

- **Tool discovery** — server asks client what browser tools are available
- **Tool execution** — server sends tool calls to the client, client returns results
- **Relay tools** — browser forwards tool calls to your dev server (for file editing, project discovery)

### How they work together

```
Client                    Server
  │                         │
  │── ACP: send prompt ────►│
  │                         │──► LLM call
  │◄── ACP: text stream ───│◄── LLM responds with tool call
  │                         │
  │◄── MCP: call tool ─────│    (e.g., "take a screenshot")
  │                         │
  │    [executes in browser] │
  │                         │
  │── MCP: tool result ────►│──► feed result to LLM
  │                         │◄── LLM responds with text
  │◄── ACP: text stream ───│
  │◄── ACP: turn complete ─│
```

---

## Server Architecture

The server is an Elixir/Phoenix application with a clear domain structure.

### Supervision Tree

All long-lived processes are supervised — if one crashes, it restarts automatically without affecting others:

```
Application
├── Repo                    PostgreSQL connection pool
├── Vault                   Encryption for API keys and tokens
├── SwarmAi.Runtime         Agent execution engine
├── ToolCallRegistry        Routes tool results to waiting executors
├── Oban                    Background jobs (emails, title generation)
├── Task.Supervisor         Ad-hoc concurrent work
├── Endpoint                HTTP + WebSocket server
└── Discord notifier        Production alerts (optional)
```

### Domain Contexts

The server code is organized into bounded contexts, each owning a specific domain:

| Context | What it does |
|---------|-------------|
| **Accounts** | User registration, authentication (email/password, GitHub, Google via WorkOS), session management |
| **Tasks** | Conversation sessions and their interactions. Each "task" is a conversation thread. Interactions are stored as typed JSONB documents (user messages, agent responses, tool calls, tool results). |
| **Execution** | Orchestrates agent runs. Builds the agent config, submits to SwarmAi Runtime, routes tool calls, persists results. |
| **Providers** | API key resolution, OAuth token management, model catalog, usage quota tracking. |
| **Tools** | Tool registry. Knows which tools exist, whether they run on the server or browser, and how to convert them for the LLM. |
| **Organizations** | Team workspaces and membership roles. |

### WebSocket Channels

Real-time communication happens over Phoenix Channels:

- **TasksChannel** (`"tasks"`) — session listing, creation, deletion, config broadcasts
- **TaskChannel** (`"task:{id}"`) — per-conversation: prompts, tool call routing, streaming responses, history loading

On join, each TaskChannel runs an **MCP initialization sequence** — a state machine that handshakes with the client to discover available tools and load project context (agent instructions, file tree).

### Data Safety: Persist-Then-Broadcast

Every interaction is written to PostgreSQL **before** being broadcast to the WebSocket. If the client disconnects mid-conversation, no data is lost. On reconnect, the full history is loaded from the database.

---

## Client Architecture

The client is written in ReScript (a typed language that compiles to JavaScript) with React for rendering.

### State Management

A custom state store built on React 18's `useSyncExternalStore`. It follows a **reducer + effects** pattern:

```
User action
  → dispatch(action)
  → reducer(state, action) → (newState, sideEffects[])
  → effects execute asynchronously (API calls, WebSocket messages)
  → results dispatch new actions back into the reducer
```

There are two reducer tiers:
- **Global reducer** — manages the task list, current selection, API key settings, OAuth status, model config
- **Task reducer** — manages per-conversation state: messages, streaming status, preview frame, annotations, plan entries

All API calls and side effects go through the reducer. Components only read state via selectors and dispatch actions — no direct fetch calls.

### Component Structure

```
App
└── FrontmanProvider          Connection management
    ├── Chatbox               Main conversation interface
    │   ├── MessageContainer   Message list
    │   ├── ToolCallBlock      Tool execution display
    │   ├── QuestionDrawer     Agent asks user for input
    │   ├── TodoListBlock      Agent's task plan
    │   ├── PlanDisplay        Step-by-step plan view
    │   ├── ThinkingIndicator  "Agent is thinking..."
    │   ├── PromptInput        Text input + attachments
    │   └── ErrorBanner        Error display
    └── WebPreview             Live app preview
        ├── Nav                URL bar + controls
        ├── DeviceBar          Responsive device selector
        ├── Body               iframe with your app
        ├── AnnotationControls Click-to-annotate mode
        └── AnnotationMarkers  Visual markers on preview
```

### Browser-Side Tools

The client registers these tools that the AI agent can call:

| Tool | What it does |
|------|-------------|
| **TakeScreenshot** | Captures the iframe as a PNG image |
| **Navigate** | Changes the iframe URL |
| **GetDom** | Serializes the DOM tree with CSS selector paths |
| **GetInteractiveElements** | Finds all buttons, inputs, links, etc. |
| **InteractWithElement** | Clicks, types, scrolls, hovers on elements |
| **SearchText** | Finds text content in the DOM |
| **SetDeviceMode** | Switches between desktop/tablet/mobile viewports |
| **Question** | Pauses the agent and asks the user a question via a UI drawer |

The **Question** tool is special — it creates a Promise that blocks the agent loop until the user responds. The user sees a drawer with the question, types an answer, and the agent continues.

---

## The Agentic Loop

The core execution engine lives in the `swarm_ai` package — a standalone Elixir library that could be used outside Frontman.

### How it works

SwarmAi uses a **pure function + effects** architecture:

```
Runner.start(loop, messages)
  → {loop, [{:call_llm, llm, messages}]}

Runner.handle_llm_response(loop, response)
  → {loop, [{:execute_tool, tool_call}, ...]}
  or
  → {loop, [{:complete, result}]}

Runner.handle_tool_result(loop, result)
  → {loop, [{:call_llm, llm, messages_with_results}]}
  or
  → {loop, []}  (still waiting for other tools)
```

The Runner is a pure state machine — it takes state and an event, returns new state and a list of effects to execute. The Runtime interprets those effects (actually calling the LLM, running tools, dispatching events).

### Loop State

Each agent run tracks:
- **Steps** — each LLM call-and-response is one step
- **Status** — ready, running, waiting_for_tools, completed, failed, paused, max_steps
- **Tool calls** — per-step, with results filled in as they complete
- **Metadata** — task ID, API key info, user context (flows through all events)

### Lifecycle Management

The Runtime supervises execution:
- Each agent run is a supervised Task process
- A linked "death watcher" process detects crashes vs. cancellations
- Duplicate runs for the same task are prevented via Registry
- Cancellation kills the process and dispatches a clean `:cancelled` event

---

## Tool Execution

When the LLM requests a tool call, the **ToolExecutor** routes it:

### Backend tools (server-side)

Executed directly in the Runtime process. Currently includes todo list management tools. The executor:
1. Looks up the tool module
2. Parses JSON arguments
3. Calls `module.execute(args, context)`
4. Persists the result to the database
5. Returns the result to the agent

### MCP tools (browser-side)

Sent to the client over WebSocket. The executor:
1. Registers itself in the ToolCallRegistry (so the result can find its way back)
2. Persists the tool call to the database
3. Sends the tool call to the client via the MCP channel
4. **Blocks** waiting for the result (60-second timeout for regular tools, 24-hour timeout for interactive tools like Question)
5. When the client responds, the channel looks up the registry and delivers the result
6. The executor unblocks and returns the result to the agent

If the client disconnects while a tool is pending, the channel's `terminate` callback sends an error result to the blocked executor — preventing a timeout hang. On reconnect, unresolved tool calls are re-dispatched to the new client.

---

## Framework Integrations

Three npm packages inject Frontman into your dev server. Each follows the same pattern: a thin framework adapter wrapping shared core logic.

### What they do

1. **Serve the Frontman UI** at a configurable base path (e.g., `/frontman/`)
2. **Expose tools** that the AI agent can call through the browser:
   - File reading and editing
   - Project structure discovery
   - Source location resolution (CSS selector → file:line)
3. **Inject annotations** that help the AI understand your component structure

### Framework-specific details

| Integration | How it hooks in | Special features |
|------------|----------------|-----------------|
| **Astro** (`@frontman-ai/astro`) | Astro integration hook + Vite middleware | Dev toolbar app, `data-astro-source-file` capture, component props injection as HTML comments |
| **Next.js** (`@frontman-ai/nextjs`) | OpenTelemetry instrumentation + client injection | Log capture integration (circular buffer) |
| **Vite** (`@frontman-ai/vite`) | Vite middleware plugin | Adapts Web API to Vite's Node.js request/response |

### Tool Relay

When the agent calls a tool that needs to run on your dev server (like reading a file), the flow is:

```
Agent → Server → Browser (MCP) → Dev Server (HTTP/SSE) → Browser → Server → Agent
```

The browser acts as a bridge — it receives the MCP tool call, forwards it to your dev server's Frontman plugin via HTTP, streams the result back via SSE, and returns it to the server.

---

## Infrastructure

### Monorepo Layout

18 Yarn workspaces across ReScript, Elixir, and Node.js:

| Directory | Contents |
|-----------|----------|
| `apps/frontman_server/` | Elixir/Phoenix backend |
| `apps/swarm_ai/` | Agentic loop runtime (standalone Hex package) |
| `apps/marketing/` | Astro static site |
| `apps/chrome-extension/` | Chrome extension |
| `libs/client/` | React UI components (ReScript) |
| `libs/frontman-client/` | ACP/Relay/MCP protocol implementation |
| `libs/frontman-protocol/` | Protocol type definitions + Sury schemas |
| `libs/frontman-core/` | Shared middleware and utilities |
| `libs/frontman-astro/` | Astro integration (npm package) |
| `libs/frontman-nextjs/` | Next.js integration (npm package) |
| `libs/frontman-vite/` | Vite integration (npm package) |
| `test/e2e/` | Playwright end-to-end tests |

### Local Development

Each developer feature branch can get its own **worktree** — an isolated copy of the repo with its own database, dev servers, and Claude Code context:

- **Process management**: mprocs (7 concurrent processes)
- **Containers**: Podman pods (PostgreSQL + dev container per worktree)
- **Routing**: Caddy reverse proxy + dnsmasq (`*.frontman.local`)
- **Secrets**: 1Password CLI (`op run --env-file`)

### Production

- **Server**: Hetzner bare metal, blue-green deployment
- **Client + Marketing**: Cloudflare Pages (static)
- **CI/CD**: GitHub Actions — build, test (8 jobs), lint, Dialyzer, Playwright E2E, deploy
