# Swarm Library Research

## Summary

Swarm is an **effect-driven, synchronous agent execution framework** that follows functional core / imperative shell principles. It executes LLM-powered agents in a loop, handling tool calls and maintaining conversation state as an inspectable data structure.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Swarm.run/4                          │
│            (Main entry point - sync execution)              │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                       Swarm.Loop                            │
│           (Inspectable execution state machine)             │
│    Status: :ready → :running → :waiting_for_tools →         │
│                    :completed | :failed | :max_steps        │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                   Swarm.Loop.Runner                         │
│           (Pure functional state transitions)               │
│     Returns: {updated_loop, [Effect.t()]}                   │
└─────────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                     Swarm.Effect                            │
│   {:call_llm, llm, messages}                                │
│   {:execute_tool, tool_call}                                │
│   {:emit_event, event}                                      │
│   {:complete, result}                                       │
│   {:fail, error}                                            │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. `Swarm` (swarm.ex)
Main entry point. The `run/4` function:
- Takes an agent, message, callbacks, and options
- Creates a `Loop` and executes it
- Interprets effects by calling LLM or tool handlers
- Uses recursion to process effect chains until completion

**Key callbacks:**
- `tool_handler` (required) - called for each tool execution
- `on_llm_call` (optional) - allows custom LLM execution (e.g., streaming)

### 2. `Swarm.Loop` (swarm/loop.ex)
Stateful data structure representing execution state:
- `id` - Unique loop ID (prefixed UUIDv7)
- `agent` - The agent being executed
- `status` - State machine (:ready → :running → :waiting_for_tools → :completed/:failed)
- `steps` - History of LLM iterations
- `current_step` - Current step number
- `result` / `error` - Final outcome

**Public API:**
- `make/2` - Create new loop from agent + config
- `execute/2` - Start execution with messages → returns effects
- `handle_response/2` - Process LLM response → returns effects
- `handle_error/2` - Process LLM error → returns effects
- `handle_tool_result/2` - Process tool result → returns effects

### 3. `Swarm.Loop.Runner` (swarm/loop/runner.ex)
Pure functional state machine - no side effects. All transitions return `{loop, effects}`.

**Flow:**
```
start/2 → {:call_llm, ...}
     ↓
handle_llm_response/2
  ├─ no tool_calls → {:complete, result}
  └─ has tool_calls → [{:execute_tool, tc}, ...]
     ↓
handle_tool_result/2
  ├─ pending tools → [] (wait)
  └─ all complete → {:call_llm, ...} (continue loop)
```

### 4. `Swarm.Agent` Protocol (swarm/agent.ex)
Defines the interface agents must implement:
- `system_prompt/1` - Returns system prompt string
- `init/1` - Returns `{:ok, state, tools}`
- `should_terminate?/3` - Custom termination logic (default: false)
- `llm/1` - Returns the LLM client to use

Supports `@derive Swarm.Agent` for basic implementation.

### 5. `Swarm.Loop.Step` (swarm/loop/step.ex)
Tracks a single LLM iteration:
- `input_messages` - Messages sent to LLM
- `content` - Response text
- `usage` - Token counts (input/output)
- `tool_calls` - List of tool calls from response
- `started_at` / `completed_at` / `duration_ms` - Timing

### 6. `Swarm.Message` (swarm/message.ex)
Message structure for LLM conversations:
- Roles: `:system`, `:user`, `:assistant`, `:tool`
- Content parts (supports multi-modal via `ContentPart`)
- Tool call association (`tool_calls`, `tool_call_id`)

Factory functions: `system/1`, `user/1`, `assistant/2`, `tool_result/3`

### 7. `Swarm.LLM` Protocol (swarm/llm.ex)
Simple protocol for LLM clients:
- `call/3` - Takes client, messages, opts → returns `{:ok, Response.t()} | {:error, term()}`

### 8. `Swarm.Effect` (swarm/effect.ex)
Union type of effects the loop can emit:
- `{:call_llm, llm, messages}` - Request LLM call
- `{:execute_tool, tool_call}` - Request tool execution
- `{:emit_event, event}` - Emit domain event
- `{:complete, result}` - Execution succeeded
- `{:fail, error}` - Execution failed

## Supporting Types

| Module | Purpose |
|--------|---------|
| `Swarm.ToolCall` | Tool call from LLM (id, name, arguments JSON, result) |
| `Swarm.ToolResult` | Result of tool execution (id, content, is_error) |
| `Swarm.LLM.Response` | Normalized LLM response (content, finish_reason, tool_calls, usage) |
| `Swarm.LLM.Usage` | Token counts (input_tokens, output_tokens) |
| `Swarm.Message.ContentPart` | Multi-modal content (:text, :image, :image_url) |
| `Swarm.Loop.Config` | Loop settings (max_steps, timeout_ms, step_timeout_ms) |
| `Swarm.Id` | Prefixed UUIDv7 generator |
| `Swarm.SpawnChildAgent` | Config for spawning child agents |

## Observability

`Swarm.Telemetry` emits `:telemetry` events:

| Event | Phase | Key Metadata |
|-------|-------|--------------|
| `[:swarm, :run, *]` | start/stop/exception | loop_id, agent_module, status, result/error |
| `[:swarm, :llm, :call, *]` | start/stop/exception | loop_id, step, model, tokens |
| `[:swarm, :tool, :execute, *]` | start/stop/exception | loop_id, step, tool_id, tool_name |

Compatible with OpenTelemetry via `opentelemetry_telemetry` library.

## Execution Flow Example

```elixir
Swarm.run(my_agent, "Hello", %{
  tool_handler: fn tc -> {:ok, "result"} end
})
```

1. `Swarm.run/4` creates `Loop.make(agent, config)`
2. Calls `Loop.execute(loop, messages)` → triggers `Runner.start/2`
3. Runner returns `{loop, [{:call_llm, llm, messages}]}`
4. `Swarm` interprets `{:call_llm, ...}` → calls `LLM.call/3`
5. Response fed to `Loop.handle_response/2` → `Runner.handle_llm_response/2`
6. If tool_calls: returns `[{:execute_tool, tc}, ...]`
7. `Swarm` calls `tool_handler` for each → `Loop.handle_tool_result/2`
8. Once all tools complete → returns `{:call_llm, ...}` (loop continues)
9. When no tool_calls: returns `{:complete, result}`
10. `Swarm.run/4` returns `{:ok, result}`

## Key Design Decisions

1. **Effect-driven** - Runner never executes side effects, only returns effect descriptions
2. **Inspectable state** - Loop struct is fully introspectable at any point
3. **Protocol-based extensibility** - `Swarm.Agent` and `Swarm.LLM` are protocols
4. **Multi-modal ready** - Messages support text, images, and URLs via ContentPart
5. **Telemetry built-in** - All operations instrumented for observability

---

# Task Persistence Research

**Date**: 2026-01-16
**Git Commit**: 4089461d678912b434c08f6c4aadb46e27fd54ce
**Branch**: feature/139-task-persistence

## Research Question

Investigate the Frontman codebase to understand how to implement persistent task storage, focusing on current task/state architecture, server infrastructure, existing persistence patterns, and client-server communication.

---

## Summary

Frontman is a Phoenix/ReScript application with:
- **Server**: Phoenix 1.8 with Ecto/PostgreSQL, WebSocket channels for real-time ACP/MCP communication
- **Client**: Custom Redux-like state store in ReScript, React 18 integration
- **Tasks are ephemeral**: Currently stored only in browser memory with no persistence to server or localStorage
- **Existing persistence**: User authentication, organizations, memberships - but no task/conversation storage
- **Communication**: WebSocket channels (JSON-RPC 2.0) + HTTP endpoints for relay tools

Implementing task persistence would require:
1. New Ecto schema(s) for tasks and messages
2. New API endpoints or channel handlers for CRUD operations
3. Client-side changes to serialize/deserialize state to/from server
4. Task loading on app initialization

---

## Detailed Findings

### 1. Current Task/State Architecture (Client-Side)

**State Management Pattern**: Custom Redux-like store using `StateStore` library

**File**: `libs/react-statestore/src/StateStore.res:1-178`

```rescript
type t<'state, 'action, 'effect> = {
  subscriptions: ref<array<unit => unit>>,
  next: ('state, 'action) => ('state, array<'effect>),  // Pure reducer
  handleEffect: ('effect, 'state, 'action => unit) => unit,  // Side effects
  effects: ref<array<'effect>>,
  state: ref<'state>,
}
```

**Main State Shape** (`libs/client/src/state/Client__State__Types.res:436-441`):
```rescript
type state = {
  tasks: Dict.t<Task.t>,           // Task dictionary keyed by ID
  currentTaskId: option<string>,   // Currently selected task
  connectionState: connectionState,
  sessionInitialized: bool,
}
```

**Task Type** (`libs/client/src/state/Client__State__Types.res:159-171`):
```rescript
type t = {
  id: string,
  title: string,
  messages: Dict.t<Message.t>,
  createdAt: float,
  lastMessageAt: option<float>,
  previewFrame: previewFrame,
  webPreviewIsSelecting: bool,
  selectedElement: option<SelectedElement.t>,
  figmaNode: FigmaNode.t,
  isAgentRunning: bool,
  planEntries: array<planEntry>,
}
```

**Message Types** (`libs/client/src/state/Client__State__Types.res:21-58`):
- `User` - User input with content parts (text, image, file)
- `Assistant` - Either `Streaming` or `Completed` with content blocks
- `ToolCall` - Tool invocations with states: `InputStreaming`, `InputAvailable`, `OutputAvailable`, `OutputError`

**Current Initialization** (`libs/client/src/Main.res:19-36`):
- On `DOMContentLoaded`, creates empty task with `Client__State.Actions.createNewTask()`
- No loading of previous tasks - starts fresh each session

**Persistence Status**: **NONE**
- Tasks exist only in browser memory
- Only UI state persisted: chatbox width via localStorage (`libs/client/src/hooks/Client__UseResizableWidth.res:14-49`)
- Snapshot system exists for debug/storybook but not used at runtime (`libs/client/src/state/Client__StateSnapshot.res`)

---

### 2. Server Infrastructure (Elixir/Phoenix)

**Stack**: Phoenix 1.8.1, Phoenix LiveView 1.1.0, Ecto 3.13, PostgreSQL

**Application Structure** (`apps/frontman_server/lib/frontman_server/application.ex:38-49`):
- `FrontmanServer.Repo` - Ecto repository
- `Phoenix.PubSub` - Real-time pub/sub
- `FrontmanServer.AgentRegistry` - Agent process tracking
- `FrontmanServer.TaskSupervisor` - Agent execution tasks
- ETS table `:tasks` for in-memory task state (line 29)

**Router** (`apps/frontman_server/lib/frontman_server_web/router.ex`):

| Scope | Path | Purpose |
|-------|------|---------|
| Public | `/` | Landing page |
| Auth (unauth) | `/users/register`, `/users/log-in` | Registration, login |
| Auth (auth) | `/users/settings` | User settings |
| Org-scoped | `/orgs/:org_slug/*` | Organization routes (empty) |

**WebSocket Channels** (`apps/frontman_server/lib/frontman_server_web/channels/`):

| Topic | Channel | Purpose |
|-------|---------|---------|
| `"tasks"` | `TasksChannel` | ACP initialization, session creation |
| `"task:*"` | `TaskChannel` | Task-specific ACP/MCP events, prompt handling |

**Channel Join Flow**:
1. Client connects to `/socket` → `UserSocket` (anonymous)
2. Joins `"tasks"` topic → `TasksChannel`
3. Sends `initialize` JSON-RPC → validates protocol version
4. Sends `session/new` → creates task via `Tasks.create_task/2`
5. Joins `"task:<id>"` topic → `TaskChannel`

**Tasks Context** (`apps/frontman_server/lib/frontman_server/tasks/`):
- Uses ETS table for in-memory storage
- `Tasks.create_task/2` - Creates task struct in ETS
- `Tasks.get_task/1` - Retrieves task from ETS
- **No database persistence** - tasks live only in ETS

---

### 3. Existing Persistence Patterns

**Database**: PostgreSQL with Ecto

**Existing Tables** (migrations in `priv/repo/migrations/`):

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `users` | id (binary_id), email (citext), name, hashed_password, confirmed_at | User accounts |
| `users_tokens` | id, user_id, token, context, sent_to, authenticated_at | Session/magic link tokens |
| `organizations` | id (binary_id), name, slug | Multi-tenant organizations |
| `memberships` | id, user_id, organization_id, role (enum) | Organization membership |

**Schema Patterns**:
- Binary UUID primary keys: `@primary_key {:id, :binary_id, autogenerate: true}`
- UTC timestamps: `timestamps(type: :utc_datetime)`
- Composable query functions in schemas
- Scope-based authorization via `%Scope{user, organization}`

**Context Patterns** (`apps/frontman_server/lib/frontman_server/accounts.ex`, `organizations.ex`):
- Public API functions with scope parameter
- Transaction wrapping via `Repo.transact/1`
- PubSub broadcasting for real-time updates

**API Response Format**: Not standardized - channels use JSON-RPC 2.0, no REST API yet

---

### 4. Client-Server Communication

**WebSocket Protocol**: Phoenix Channels with JSON-RPC 2.0 messages

**ACP (Agent Client Protocol)** - Client → Server:
- `initialize` - Protocol handshake
- `session/new` - Create new task/session
- `session/prompt` - Send user prompt

**ACP Notifications** - Server → Client:
- `AgentMessageChunk` - Streaming text
- `ToolCall` - Tool invocation
- `ToolCallUpdate` - Tool result
- `Plan` - Agent plan updates

**MCP (Model Context Protocol)** - Server → Browser:
- Browser acts as MCP server
- Responds to `tools/list`, `tools/call` requests
- Executes browser-side tools (DOM inspection, etc.)

**HTTP Endpoints** (Relay):
- `GET /__frontman/tools` - Discover relay tools
- `POST /__frontman/tools/call` - Execute relay tool (SSE response)
- `POST /__frontman/resolve-source-location` - Resolve source maps

**Client HTTP Pattern** (`libs/frontman-client/src/FrontmanClient__Relay.res`):
```rescript
let response = await WebAPI.Global.fetch(url, ~init={
  method: "POST",
  headers: {"Content-Type": "application/json"},
  body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
})
```

---

### 5. Key Files Located

**Task/Message Type Definitions**:
- `libs/client/src/state/Client__State__Types.res` - Main state types
- `libs/frontman-client/src/FrontmanClient__ACP__Types.res` - ACP protocol types
- `libs/frontman-protocol/src/FrontmanProtocol__MCP.res` - MCP protocol types

**State Management**:
- `libs/react-statestore/src/StateStore.res` - Store implementation
- `libs/client/src/state/Client__State__Store.res` - Store instantiation
- `libs/client/src/state/Client__State__StateReducer.res` - Reducer + effects
- `libs/client/src/state/Client__State.res` - Public API

**Server Router/Controllers**:
- `apps/frontman_server/lib/frontman_server_web/router.ex` - Routes
- `apps/frontman_server/lib/frontman_server_web/channels/tasks_channel.ex` - Session init
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex` - Task events
- `apps/frontman_server/lib/frontman_server/tasks/` - Tasks context (ETS-based)

**Existing Ecto Schemas**:
- `apps/frontman_server/lib/frontman_server/accounts/user.ex`
- `apps/frontman_server/lib/frontman_server/accounts/user_token.ex`
- `apps/frontman_server/lib/frontman_server/organizations/organization.ex`
- `apps/frontman_server/lib/frontman_server/organizations/membership.ex`

**API Client Utilities**:
- `libs/frontman-client/src/FrontmanClient__Phoenix__Socket.res` - Socket bindings
- `libs/frontman-client/src/FrontmanClient__Phoenix__Channel.res` - Channel bindings
- `libs/frontman-client/src/FrontmanClient__ACP.res` - ACP connection
- `libs/frontman-client/src/FrontmanClient__JsonRpc.res` - JSON-RPC helpers

---

## Architecture Documentation

### State Flow

```
User Input (PromptInput)
    │
    ▼
dispatch(AddUserMessage) ───────────────────────────────────────────┐
    │                                                                │
    ▼                                                                │
StateReducer.next() ─────► (newState, [SendMessageToAPI effect])    │
    │                                                                │
    ▼                                                                │
handleEffect(SendMessageToAPI) ─────► connection.sendPrompt()       │
    │                                                                │
    ▼                                                                │
Phoenix Channel ─────► "acp:message" ─────► session/prompt          │
    │                                                                │
    ▼                                                                │
Swarm Agent Execution                                                │
    │                                                                │
    ▼                                                                │
"session/update" notifications ─────────────────────────────────────┘
    │
    ▼
handleSessionUpdate() ─────► dispatch(StreamingStarted, TextDeltaReceived, etc.)
    │
    ▼
StateReducer.next() ─────► updated state
    │
    ▼
React re-render via useSyncExternalStore
```

### Current Task Lifecycle

1. **Creation**: `DOMContentLoaded` → `createNewTask()` → empty task in memory
2. **WebSocket Connect**: Join `"tasks"` → `initialize` → `session/new` → Join `"task:<id>"`
3. **Prompt**: User types → `AddUserMessage` → `sendPrompt` → agent executes
4. **Streaming**: Server pushes `session/update` → reducer updates messages
5. **Termination**: Tab close → all data lost (no persistence)

### Authentication Flow

```
Register/Login ─────► UserSession ─────► Cookie (14-day validity)
       │
       ▼
fetch_current_scope_for_user plug ─────► Scope{user, organization}
       │
       ▼
require_authenticated_user plug ─────► 403 or continue
```

---

## Open Questions

1. **Task-User Association**: Should tasks belong to a user, organization, or both?
2. **Message Storage**: Store as JSON blob or normalized relational tables?
3. **Partial Sync**: How to handle tasks created offline?
4. **Retention Policy**: How long to keep task history?
5. **Channel Authentication**: Currently anonymous - needs authentication for persistence
6. **ETS Migration**: How to migrate from ETS to Ecto without breaking existing functionality?

---

## Implementation Considerations

### What Exists That You Can Build On

1. **Server Infrastructure**
   - Phoenix 1.8 + Ecto + PostgreSQL fully set up
   - Existing schemas for users, organizations, memberships follow good patterns (binary UUIDs, UTC timestamps, composable queries, scope-based auth)
   - WebSocket channels already handle task creation and messaging (`TasksChannel`, `TaskChannel`)

2. **Client State**
   - Well-structured Redux-like store with types at `libs/client/src/state/Client__State__Types.res`
   - Snapshot serialization already exists for debug/storybook (`Client__StateSnapshot.res`)
   - Clean separation: pure reducer + side effects

3. **Communication**
   - JSON-RPC 2.0 over Phoenix Channels already working
   - HTTP fetch patterns established in `FrontmanClient__Relay.res`

### What Needs Building

1. **Ecto Schema(s)** for tasks and messages (follow existing patterns in `accounts/`, `organizations/`)
2. **Tasks Context** - replace ETS-based storage with Ecto
3. **Channel Authentication** - associate socket with user scope
4. **Client Persistence Layer** - serialize state to server on changes, load on startup
5. **API Endpoints** (or channel handlers) for task CRUD
