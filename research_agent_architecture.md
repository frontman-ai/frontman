---
date: 2025-12-31T16:11:08+01:00
researcher: BlueHotDog
git_commit: cbe048d29ef35a461562b46e44dca5581716065a
branch: improving_agent
repository: frontman
topic: "Agent Definition, Agentic Loop, and Agent-Tool Relationships"
tags: [research, codebase, agents, agentic-loop, tools, domain-architecture]
status: complete
last_updated: 2025-12-31
last_updated_by: BlueHotDog
---

# Research: Agent Definition, Agentic Loop, and Agent-Tool Relationships

**Date**: 2025-12-31T16:11:08+01:00
**Researcher**: BlueHotDog
**Git Commit**: cbe048d29ef35a461562b46e44dca5581716065a
**Branch**: improving_agent
**Repository**: frontman

## Research Question

How are agents defined, how does the agentic loop work, and what is the relationship between agents, tools, and the agentic loop in the frontman_server domain code?

## Summary

The frontman_server implements an event-driven agentic system where **agents** are GenServer processes that execute LLM iterations, **tools** are executable capabilities (backend or MCP), and the **agentic loop** is a push-based iteration cycle that coordinates LLM calls, tool execution, and state transitions. The architecture uses a clear separation between domain logic (Agent struct), infrastructure (AgentServer GenServer), and coordination (Agents API module), with Registry-based routing enabling direct message passing between components.

### Key Architectural Patterns

1. **Domain-Driven Separation**: Pure domain structs (Agent) separate from infrastructure (AgentServer)
2. **Push Model**: Agents receive all data via messages and callbacks, with no direct coupling to Tasks or PubSub
3. **Event-Driven Coordination**: All state changes emit events that are translated to persistence and broadcasts
4. **Registry-Based Routing**: O(1) direct routing from tool results to owning agents using Registry lookups
5. **Behaviour-Based Tool System**: Tools implement a common Backend behaviour with unified registration and execution
6. **Synchronous Sub-Agents**: Backend tools can spawn nested agents that block until completion

## Detailed Findings

### 1. Agent Definition and Structure

#### Agent Domain Entity

The Agent is a pure domain struct at `apps/frontman_server/lib/frontman_server/agents/agent.ex:13-19`:

```elixir
typedstruct enforce: true do
  field :id, String.t()                           # Unique agent identifier
  field :task_id, String.t()                      # Parent task reference
  field :pending_tools, %{String.t() => ToolCall.t()}, default: %{}  # In-flight tools
  field :started_at, integer(), default: 0        # Monotonic timestamp
  field :iteration_count, non_neg_integer(), default: 0  # LLM call counter
end
```

**Pure Functional Design**: All operations return new Agent structs without side effects:

- `new_root/2` (`agent.ex:22-29`) - Creates agent with initial state
- `has_pending_work?/1` (`agent.ex:32-35`) - Returns `map_size(pending_tools) > 0`
- `track_tool/2` (`agent.ex:38-41`) - Adds tool call to `pending_tools` map
- `complete_tool/2` (`agent.ex:44-50`) - Removes tool call, returns `{tool_call, updated_agent}`
- `increment_iteration/1` (`agent.ex:53-56`) - Increments iteration counter

**Pending Tools Map**: The `pending_tools` field is central to agent state management:
- **Track**: Tool calls added via `track_tool/2` when LLM responds
- **Wait**: Agent waits while `has_pending_work?/1` returns true
- **Complete**: Tools removed via `complete_tool/2` as results arrive
- **Trigger**: When map becomes empty, next iteration is triggered

#### AgentServer Process

The AgentServer GenServer at `apps/frontman_server/lib/frontman_server/agents/agent_server.ex:28-36` manages agent lifecycle:

```elixir
defstruct [
  :agent,              # Agent domain struct
  :tools,              # List of ReqLLM.Tool structs for LLM
  :on_event,           # Event callback function
  :idle_timer_ref,     # Timer reference for idle timeout
  :parent_agent_id,    # Parent ID if sub-agent
  status: :processing, # :processing | :waiting_for_tools | :idle
  llm_opts: []         # LLM options (e.g., test fixtures)
]
```

**Process Registration** (`agent_server.ex:73-81`):
- **Registry Key**: `{:agent, agent_id}`
- **Registry Value**: GenServer PID
- **Metadata**: `%{task_id:, parent_agent_id:, role:, spawning_tool_name:}`

**Status Transitions**:
- `:processing` → Executing iteration
- `:waiting_for_tools` → Tool calls pending
- `:idle` → Waiting for user message
- Terminated → After 5-minute idle timeout

#### Agent Orchestration API

The Agents module at `apps/frontman_server/lib/frontman_server/agents.ex` provides the public API:

- `start_agent/2` (`agents.ex:116`) - Spawns agent, builds event handler, triggers first iteration
- `notify_tool_result/4` (`agents.ex:162`) - Routes tool results via Registry lookup
- `notify_user_message/2` (`agents.ex:182`) - Wakes idle agent or spawns new one
- `execute_sub_agent/3` (`agents.ex:207`) - Runs nested agent synchronously
- `agent_state/1` (`agents.ex:28`) - Queries current agent status
- `agent_running?/1` (`agents.ex:39`) - Checks if agent exists

### 2. The Agentic Loop Implementation

The agentic loop is a multi-stage iteration cycle coordinated between AgentServer, the Agents API, and the Tasks context.

#### Loop Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AGENTIC LOOP CYCLE                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. START ITERATION                                         │
│     ├─ Get messages from Tasks                             │
│     ├─ Build system prompt                                 │
│     └─ Call AgentServer.execute_iteration/2                │
│                                                             │
│  2. LLM EXECUTION (AgentServer)                            │
│     ├─ Increment iteration counter                         │
│     ├─ Stream LLM response                                 │
│     ├─ Emit {:token, ...} events during streaming          │
│     ├─ Extract tool calls from stream                      │
│     └─ Handle response                                     │
│                                                             │
│  3. RESPONSE HANDLING                                       │
│     ├─ No tools: Emit {:completed, ...} → STOP            │
│     └─ Has tools: Emit {:response, ...} → WAIT            │
│                                                             │
│  4. TOOL TRACKING (if tools present)                       │
│     ├─ Emit {:tool_call, ...} for each tool               │
│     ├─ Register in Registry: {:tool_call, id} → agent_id  │
│     ├─ Track in Agent.pending_tools map                   │
│     └─ Set status: :waiting_for_tools                     │
│                                                             │
│  5. TOOL EXECUTION (external to agent)                     │
│     ├─ Event handler calls Tasks.add_tool_call/3          │
│     ├─ Broadcast via PubSub to channel                    │
│     ├─ Channel routes to backend or MCP                   │
│     └─ Tool executes asynchronously                       │
│                                                             │
│  6. TOOL RESULT ARRIVAL                                    │
│     ├─ Agents.notify_tool_result/4                        │
│     ├─ Registry lookup: {:tool_call, id} → agent_id       │
│     ├─ Send {:tool_result, ...} to AgentServer            │
│     └─ AgentServer.complete_tool/2 removes from pending   │
│                                                             │
│  7. CHECK PENDING WORK                                     │
│     ├─ If Agent.has_pending_work?/1 is true → WAIT        │
│     └─ If no pending work → Emit {:need_iteration, ...}   │
│                                                             │
│  8. NEXT ITERATION (event handler)                         │
│     ├─ Agents.push_iteration/2                            │
│     ├─ Get updated messages (includes tool results)       │
│     └─ Go to step 1                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Phase 1: Iteration Start

**Entry point**: `Agents.start_agent/2` (`agents.ex:116-150`) or `Agents.push_iteration/2` (`agents.ex:240-253`)

**Process** (`agents.ex:144, 252`):
1. Retrieve conversation messages from Tasks
2. Gather context flags (Figma availability, framework setting)
3. Build system prompt via `Prompts.build_system_message/2`
4. Call `AgentServer.execute_iteration/2` with messages

**Message handler** (`agent_server.ex:155-187`):
```elixir
def handle_info({:execute_iteration, messages}, state) do
  agent = Agent.increment_iteration(state.agent)
  state = %{state | agent: agent, status: :processing}

  TelemetryEvents.iteration_start(agent.id, agent.iteration_count)

  case stream_and_handle_response(state, messages) do
    {:wait_for_tools, state} -> # Tools pending
    {:stop, state} -> # Agent complete
    {:error, reason, state} -> # Error occurred
  end
end
```

#### Phase 2: LLM Streaming

**LLM call** (`agent_server.ex:256-332`):
```elixir
defp stream_and_handle_response(state, messages) do
  # Build options with API key and tools
  llm_opts =
    state.llm_opts
    |> Keyword.put(:api_key, get_api_key(@default_model))
    |> then(fn opts ->
      case state.tools do
        [] -> opts
        tools -> Keyword.put(opts, :tools, tools)
      end
    end)

  # Emit telemetry and call LLM
  TelemetryEvents.llm_start(agent_id, task_id, @default_model, messages)

  case ReqLLM.stream_text(@default_model, messages, llm_opts) do
    {:ok, response} ->
      # Stream chunks and emit {:token, ...} events
      chunks = stream_chunks(state, response.stream)

      # Extract data
      text = Enum.map_join(chunks, "", fn chunk -> chunk.text || "" end)
      tool_calls = StreamParser.extract_tool_calls(chunks)
      response_id = extract_response_id(chunks)
      reasoning_details = extract_reasoning_details(chunks)

      # Handle response
      handle_response(state, text, tool_calls, response_id, reasoning_details)

    {:error, reason} ->
      {:error, reason, state}
  end
end
```

**Token streaming** (`agent_server.ex:334-345`):
```elixir
defp stream_chunks(state, stream) do
  stream
  |> Enum.map(fn chunk ->
    if chunk.text && chunk.text != "" do
      emit(state, {:token, state.agent.id, chunk.text})
    end
    chunk
  end)
end
```

#### Phase 3: Stream Parsing

**Tool call extraction** (`stream_parser.ex:20-27`):
```elixir
def extract_tool_calls(chunks) do
  raw_calls = extract_raw_tool_calls(chunks)          # Get base calls
  arg_fragments = collect_argument_fragments(chunks)  # Get streamed args

  Enum.map(raw_calls, fn call ->
    args = resolve_arguments(call, arg_fragments)     # Merge args
    tool_call_from_raw(call.id, call.name, args)
  end)
end
```

**Process**:
1. **Extract base calls** - Filter chunks where `type == :tool_call`
2. **Collect fragments** - Filter `:meta` chunks with `tool_call_args`, group by index, concatenate
3. **Resolve arguments** - Use fragments if available, fall back to inline arguments
4. **Create ToolCall** - Convert to `ReqLLM.ToolCall` struct with JSON-encoded arguments

#### Phase 4: Response Handling

**No tool calls** (`agent_server.ex:347-351`):
```elixir
def handle_response(state, text, [], _response_id, _reasoning_details) do
  emit(state, {:response, state.agent.id, text, %{}})
  {:stop, state}
end
```

**With tool calls** (`agent_server.ex:353-376`):
```elixir
def handle_response(state, text, tool_calls, response_id, reasoning_details)
    when length(tool_calls) > 0 do
  # Build metadata
  metadata =
    %{tool_calls: tool_calls}
    |> maybe_add(:response_id, response_id)
    |> maybe_add(:reasoning_details, reasoning_details)

  # Emit response event
  emit(state, {:response, state.agent.id, text, metadata})

  # Track all tool calls
  state = track_tool_calls(state, tool_calls)

  # Wait if pending work, else stop
  if Agent.has_pending_work?(state.agent) do
    {:wait_for_tools, state}
  else
    {:stop, state}
  end
end
```

#### Phase 5: Tool Tracking

**Track tool calls** (`agent_server.ex:380-389`):
```elixir
defp track_tool_calls(state, tool_calls) do
  agent = Enum.reduce(tool_calls, state.agent, fn tc, agent ->
    # Emit tool call event
    emit(state, {:tool_call, agent.id, tc})

    # Register in Registry
    Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tc.id}, agent.id)

    # Track in Agent domain
    Agent.track_tool(agent, tc)
  end)

  %{state | agent: agent}
end
```

**State after tracking**:
- Status: `:waiting_for_tools`
- `pending_tools`: Map of `tool_call_id → ToolCall` structs
- Registry: `{:tool_call, id} → agent_id` entries created
- Events: `{:tool_call, agent_id, tool_call}` emitted for each tool

#### Phase 6: Event Handling

**Event handler callback** (`agents.ex:217-238`):
```elixir
defp handle_agent_event(task_id, event) do
  case event do
    {:token, agent_id, token} ->
      broadcast(task_id, {:agent_stream_token, agent_id, token})

    {:response, agent_id, text, metadata} ->
      Tasks.add_agent_response(task_id, agent_id, text, metadata)

    {:tool_call, agent_id, tool_call} ->
      Tasks.add_tool_call(task_id, agent_id, tool_call)

    {:completed, agent_id} ->
      Tasks.add_agent_completed(task_id, agent_id)
      broadcast(task_id, {:agent_completed, agent_id})

    {:error, agent_id, reason} ->
      broadcast(task_id, {:agent_error, agent_id, inspect(reason)})

    {:need_iteration, agent_id} ->
      push_iteration(task_id, agent_id)
  end
end
```

**Flow**:
1. `{:tool_call, ...}` → `Tasks.add_tool_call/3` persists and broadcasts via PubSub
2. Task channel receives broadcast
3. Channel routes to backend tool executor or MCP client
4. Tool executes asynchronously

#### Phase 7: Tool Result Handling

**Result arrival** (`agents.ex:162-169`):
```elixir
def notify_tool_result(task_id, tool_call_id, result, is_error) do
  with {:ok, agent_id} <- get_agent_for_tool_call(tool_call_id),
       {:ok, pid} <- get_agent(agent_id) do
    send(pid, {:tool_result, tool_call_id, result, is_error})
    :ok
  else
    {:error, _} -> {:error, :agent_not_found}
  end
end
```

**AgentServer handler** (`agent_server.ex:191-212`):
```elixir
def handle_info({:tool_result, tool_call_id, _result, _is_error}, state) do
  {tool_call, agent} = Agent.complete_tool(state.agent, tool_call_id)

  if tool_call do
    # Unregister from Registry
    Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})

    state = %{state | agent: agent}

    # Check if all tools complete
    if Agent.has_pending_work?(agent) do
      # Still has pending tools, keep waiting
      state = schedule_idle_timeout(state)
      {:noreply, state}
    else
      # All tools complete, request next iteration
      cancel_idle_timeout(state)
      emit(state, {:need_iteration, agent.id})
      {:noreply, state}
    end
  else
    {:noreply, state}
  end
end
```

#### Phase 8: Next Iteration

**Iteration trigger** (`agents.ex:235-236`):
```elixir
{:need_iteration, agent_id} ->
  push_iteration(task_id, agent_id)
```

**Push iteration** (`agents.ex:240-253`):
```elixir
defp push_iteration(task_id, agent_id) do
  messages = Tasks.get_llm_messages(task_id, agent_id)
  framework = get_framework(task_id)

  context = %{
    has_figma_node: figma_node_present?(task_id),
    has_selected_component: selected_component_present?(task_id),
    framework: framework,
    figma_node_id: get_figma_node_id(task_id)
  }

  system_msg = Prompts.build_system_message(context, task_id)
  AgentServer.execute_iteration(agent_id, [system_msg | messages])
end
```

**Cycle completion**: Returns to Phase 1 with updated messages including tool results

### 3. Relationship Between Agents, Tools, and the Agentic Loop

#### Tool Architecture

**Backend Tools** are server-side executable capabilities defined in `apps/frontman_server/lib/frontman_server/tools/`:

**Registration** (`tools.ex:13-22`):
```elixir
@backend_tools [
  FrontmanServer.Tools.TodoList,
  FrontmanServer.Tools.TodoAdd,
  FrontmanServer.Tools.TodoUpdate,
  FrontmanServer.Tools.TodoRemove,
  FrontmanServer.Tools.BreakdownFigmaDesign,
  FrontmanServer.Tools.ImplementComponent,
  FrontmanServer.Tools.FinishComponent,
  FrontmanServer.Tools.MakeComponentPixelPerfect
]
```

**Backend Behaviour** (`tools/backend.ex:21-26`):
```elixir
@callback name() :: String.t()
@callback description() :: String.t()
@callback parameter_schema() :: map()
@callback execute(args :: map(), context :: Context.t()) :: result()
```

**Execution Context** (`tools/backend.ex:6-19`):
```elixir
typedstruct do
  field :task, Task.t(), enforce: true      # Task state
  field :agent_id, String.t(), enforce: true  # Calling agent
  field :llm_opts, keyword(), default: []   # LLM options
end
```

#### Tool-LLM Integration

**Tool preparation** (`tools.ex:52-64`):
```elixir
def prepare_for_task(mcp_tools, task_id) do
  # Store MCP tools on task for backend tools to access
  if mcp_tools != [] do
    Tasks.set_mcp_tools(task_id, mcp_tools)
  end

  # Aggregate all tools
  mcp_formatted = FrontmanServer.Tools.MCP.to_llm_format(mcp_tools)
  backend = backend_tools()

  backend ++ mcp_formatted
end
```

**Conversion to LLM format** (`tools/backend.ex:28-37`):
```elixir
def to_llm_tool(module) do
  ReqLLM.Tool.new!(
    name: module.name(),
    description: module.description(),
    parameter_schema: module.parameter_schema(),
    callback: fn _args -> {:ok, nil} end  # Dummy - intercepted at channel
  )
end
```

**Tools passed to agent** (`agents.ex:116-125`):
```elixir
def start_agent(task_id, opts \\ []) do
  tools = Keyword.get(opts, :tools, [])  # Prepared tools from prepare_for_task/2
  on_event = build_event_handler(task_id)

  DynamicSupervisor.start_child(
    FrontmanServer.AgentSupervisor,
    {AgentServer, agent_id: agent_id, task_id: task_id, tools: tools, on_event: on_event}
  )
end
```

**Tools in LLM call** (`agent_server.ex:263-268`):
```elixir
llm_opts = then(fn opts ->
  case state.tools do
    [] -> opts
    tools -> Keyword.put(opts, :tools, tools)
  end
end)
```

#### Tool Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   TOOL EXECUTION FLOW                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. LLM RETURNS TOOL CALLS                                 │
│     └─ StreamParser.extract_tool_calls/1 creates ToolCall  │
│                                                             │
│  2. AGENT EMITS EVENTS                                     │
│     ├─ {:tool_call, agent_id, tool_call}                  │
│     └─ Event handler → Tasks.add_tool_call/3              │
│                                                             │
│  3. PUBSUB BROADCAST                                       │
│     └─ Channel receives {:interaction, ToolCall}          │
│                                                             │
│  4. TOOL ROUTING (channel)                                 │
│     ├─ Check Tools.find_tool/1                            │
│     ├─ If backend → Execute async                         │
│     └─ If not found → Route to MCP                        │
│                                                             │
│  5. BACKEND TOOL EXECUTION                                 │
│     ├─ Tools.execute_backend_tool/2                       │
│     ├─ Build Backend.Context                              │
│     ├─ Call tool.execute/2                                │
│     └─ Return {:executed, {:ok, result}}                  │
│                                                             │
│  6. RESULT ROUTING                                         │
│     ├─ Channel calls Tasks.add_tool_result/5              │
│     ├─ Tasks calls Agents.notify_tool_result/4            │
│     └─ Registry lookup → Send to AgentServer              │
│                                                             │
│  7. AGENT RESUMES                                          │
│     ├─ AgentServer.complete_tool/2                        │
│     ├─ Check has_pending_work?/1                          │
│     └─ If false → Emit {:need_iteration, ...}             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Sub-Agent Tool Pattern

Complex tools like `BreakdownFigmaDesign` and `ImplementComponent` spawn nested agents:

**Sub-agent execution** (`agents/sub_agent_executor.ex:49-104`):
```elixir
def execute(task_id, messages, opts) do
  agent_id = Ecto.UUID.generate()
  caller = self()
  tools = Keyword.get(opts, :tools, [])
  timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

  # Build event handler that sends messages to caller
  on_event = build_event_handler(caller, agent_id, task_id)

  # Start sub-agent
  {:ok, _pid} = DynamicSupervisor.start_child(
    FrontmanServer.AgentSupervisor,
    {AgentServer,
     agent_id: agent_id,
     task_id: task_id,
     tools: tools,
     on_event: on_event,
     parent_agent_id: parent_agent_id,
     spawning_tool_name: spawning_tool_name}
  )

  # Trigger first iteration
  AgentServer.execute_iteration(agent_id, messages)

  # Block until completion
  await_result_loop(agent_id, task_id, caller, "", timeout)
end
```

**Blocking loop** (`sub_agent_executor.ex:133-176`):
```elixir
defp await_result_loop(agent_id, task_id, caller, accumulated_response, timeout) do
  receive do
    {:sub_agent_response, ^agent_id, text} ->
      await_result_loop(agent_id, task_id, caller, accumulated_response <> text, timeout)

    {:sub_agent_completed, ^agent_id} ->
      {:ok, accumulated_response}

    {:sub_agent_error, ^agent_id, reason} ->
      {:error, reason}

    {:sub_agent_tool_call, ^agent_id, tool_call} ->
      Tasks.add_tool_call(task_id, agent_id, tool_call)
      await_result_loop(agent_id, task_id, caller, accumulated_response, timeout)

    {:sub_agent_need_iteration, ^agent_id} ->
      push_sub_agent_iteration(agent_id, task_id, messages)
      await_result_loop(agent_id, task_id, caller, accumulated_response, timeout)
  after
    timeout -> {:error, :timeout}
  end
end
```

**Example: BreakdownFigmaDesign** (`tools/breakdown_figma_design.ex:111-147`):
```elixir
def execute(args, %Context{task: task, agent_id: parent_agent_id}) do
  node_id = args["nodeId"]

  # Get MCP tools from task
  mcp_tools = MCP.to_llm_format(task.mcp_tools)

  # Build messages for sub-agent
  system_msg = %{role: "system", content: @system_prompt}
  user_msg = build_user_message(task.task_id, node_id)

  # Execute sub-agent and block
  case Agents.execute_sub_agent(
    task.task_id,
    [system_msg, user_msg],
    tools: mcp_tools,
    role: "figma_breakdown",
    parent_agent_id: parent_agent_id,
    spawning_tool_name: name()
  ) do
    {:ok, result} -> {:ok, %{"breakdown" => result, "nodeId" => node_id}}
    {:error, reason} -> {:error, "Breakdown failed: #{inspect(reason)}"}
  end
end
```

#### Agent-Tool Integration Points

**1. Tool Registration** (`tools.ex:13-22`):
- Backend tools register via `@backend_tools` list
- MCP tools registered dynamically from client
- Combined in `prepare_for_task/2`

**2. Tool Discovery** (`agents.ex:118, agent_server.ex:263-268`):
- Tools passed to AgentServer on startup
- Tools added to LLM options during streaming

**3. Tool Invocation** (`agent_server.ex:380-389`):
- LLM returns tool calls
- StreamParser extracts to ToolCall structs
- Agent tracks in `pending_tools` map
- Events emitted to trigger execution

**4. Tool Execution** (`tools.ex:66-104`):
- Channel routes based on `Tools.find_tool/1`
- Backend tools execute via `Tools.execute_backend_tool/2`
- Context built with task and agent_id
- Tool module's `execute/2` called

**5. Result Routing** (`agents.ex:162-169`):
- Registry lookup by `{:tool_call, tool_call_id}`
- Direct send to AgentServer PID
- Tool removed from `pending_tools`

**6. Iteration Resume** (`agent_server.ex:204-207`):
- When `pending_tools` empty, emit `{:need_iteration, ...}`
- Event handler calls `push_iteration/2`
- New iteration includes tool results in message history

## Code References

### Agent Definition
- `apps/frontman_server/lib/frontman_server/agents/agent.ex:13-19` - Agent domain struct
- `apps/frontman_server/lib/frontman_server/agents/agent_server.ex:28-36` - AgentServer state
- `apps/frontman_server/lib/frontman_server/agents.ex:116` - Agent startup API

### Agentic Loop
- `apps/frontman_server/lib/frontman_server/agents/agent_server.ex:155-187` - Iteration handler
- `apps/frontman_server/lib/frontman_server/agents/agent_server.ex:256-332` - LLM streaming
- `apps/frontman_server/lib/frontman_server/agents/agent_server.ex:347-376` - Response handling
- `apps/frontman_server/lib/frontman_server/agents.ex:240-253` - Iteration orchestration

### Stream Parsing
- `apps/frontman_server/lib/frontman_server/agents/stream_parser.ex:20-27` - Tool call extraction
- `apps/frontman_server/lib/frontman_server/agents/stream_parser.ex:44-55` - Raw call extraction
- `apps/frontman_server/lib/frontman_server/agents/stream_parser.ex:57-68` - Fragment collection

### Tool System
- `apps/frontman_server/lib/frontman_server/tools.ex:13-22` - Backend tool registration
- `apps/frontman_server/lib/frontman_server/tools/backend.ex:21-26` - Backend behaviour
- `apps/frontman_server/lib/frontman_server/tools.ex:66-104` - Tool execution
- `apps/frontman_server/lib/frontman_server/tools.ex:52-64` - Tool preparation

### Agent-Tool Integration
- `apps/frontman_server/lib/frontman_server/agents/agent_server.ex:380-389` - Tool tracking
- `apps/frontman_server/lib/frontman_server/agents/agent_server.ex:191-212` - Tool result handling
- `apps/frontman_server/lib/frontman_server/agents.ex:162-169` - Result routing
- `apps/frontman_server/lib/frontman_server/agents/sub_agent_executor.ex:49-104` - Sub-agent execution

### Event System
- `apps/frontman_server/lib/frontman_server/agents.ex:213-238` - Event handler
- `apps/frontman_server/lib/frontman_server/agents/agent_server.ex:249-252` - Event emission
- `apps/frontman_server/lib/frontman_server/agents.ex:119` - Event handler creation

## Architecture Documentation

### Domain Separation

The system follows a strict separation of concerns:

**Domain Layer** (`agents/agent.ex`):
- Pure functional state management
- No I/O, no side effects
- Typed structs with validation
- Domain operations as pure functions

**Infrastructure Layer** (`agents/agent_server.ex`):
- GenServer process management
- Message handling
- Registry integration
- Timeout management
- Event emission

**Coordination Layer** (`agents.ex`):
- Public API boundary
- Event handler construction
- Registry-based routing
- Task integration

### Communication Patterns

**Push Model**:
- Agents receive all data via `{:execute_iteration, messages}`
- No polling or pulling from Tasks
- Events emitted via callbacks, not direct calls

**Registry-Based Routing**:
- `{:agent, agent_id} → PID` for agent lookup
- `{:tool_call, tool_call_id} → agent_id` for result routing
- O(1) direct message passing

**Event-Driven Updates**:
- All state changes emit events
- Event handler translates to persistence and broadcasts
- Clear separation between agent logic and infrastructure

### Process Supervision

**Supervisor Hierarchy** (`application.ex:34-36`):
```
FrontmanServer.Application
  ├─ FrontmanServer.AgentRegistry (Registry)
  └─ FrontmanServer.AgentSupervisor (DynamicSupervisor)
       ├─ AgentServer (root agent 1)
       ├─ AgentServer (root agent 2)
       ├─ AgentServer (sub-agent 1)
       └─ ...
```

**Process Lifecycle**:
- Agents spawn on first user message or explicit start
- Agents idle after 5 minutes of inactivity
- Agents can be woken by user messages
- Sub-agents terminate after completion
- Root agents terminate on timeout or error

### Data Flow Patterns

**Message History Management**:
- Tasks stores all interactions
- Agent retrieves messages for each iteration
- Messages include user prompts, agent responses, tool calls, tool results
- System prompt rebuilt with current context for each iteration

**Tool Result Tracking**:
- Tool calls registered in Registry during tracking
- Results route directly via Registry lookup
- Tool removed from `pending_tools` on result arrival
- Iteration triggered when all tools complete

**Sub-Agent Isolation**:
- Sub-agents use same infrastructure as root agents
- Event handler sends messages to caller instead of Tasks
- Caller blocks with receive loop
- Sub-agent context isolated from parent

## Related Research

This research focuses on the domain implementation in `apps/frontman_server/lib/frontman_server/`. For web/channel integration, see the TaskChannel implementation in `apps/frontman_server/lib/frontman_server_web/channels/`.
