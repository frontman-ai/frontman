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
