# Swarm Architecture Specification

---

## Summary

The `swarm_ai` package implements a **functional core, imperative shell** architecture for executing AI loops. It orchestrates LLM interactions and tool execution through a pure functional state machine that produces **effects** (instructions for side effects) which are interpreted by an impure execution layer.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          SwarmAi Module (Impure Shell)              │
│   - Interprets effects                                              │
│   - Makes LLM API calls                                             │
│   - Executes tools                                                  │
└────────────────────────────────────┬────────────────────────────────┘
                                     │ produces/consumes
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Loop + Runner (Pure Functional Core)             │
│   - State machine for agent execution                               │
│   - Returns {loop, effects} tuples                                  │
│   - No side effects                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### Public Runtime API (`swarm_ai.ex`)

`SwarmAi.run/2` accepts a `Loop` with task identity, messages, an LLM client, and tool and event callbacks.

### Loop State Machine (`loop.ex`, `loop/`)

The `SwarmAi.Loop` struct tracks execution state:

| Field | Purpose |
|-------|---------|
| `id` | UUIDv7-based unique identifier |
| `task_id`, `turn_number` | Task and turn identity |
| `status` | `:ready`, `:running`, `:waiting_for_tools`, `:completed`, `{:failed, reason}` |
| `steps` | History of all execution steps |

**Status Transitions:**
```
:ready → :running → :waiting_for_tools → :running → ... → :completed
                                                       ↘ :failed
```

### Runner (`loop/runner.ex`)

Pure functional module that produces effects without performing side effects:

```elixir
{loop, effects} = Loop.execute(loop)
```

### Effect System (`effect.ex`)

Effects are tagged tuples representing instructions:

| Effect | Action |
|--------|--------|
| `{:call_llm, llm, messages}` | Make an LLM API call |
| `{:execute_tool, tool_call}` | Execute a tool |
| `{:step_ended, step}` | A step completed |
| `{:complete, result}` | Loop finished successfully |
| `{:fail, error}` | Loop failed |

### LLM Integration (`llm.ex`, `llm/`)

Protocol-based streaming interface:

```elixir
@spec stream(t, [Message.t()], keyword()) :: {:ok, Enumerable.t(ReqLLM.StreamChunk.t())} | {:error, term()}
```

**Chunk Types**: `:content`, `:thinking`, `:tool_call`, `:meta`

Production implementations should implement this protocol to support their preferred LLM providers.

### Message System (`message.ex`, `message/`)

Messages have roles (`:system`, `:user`, `:assistant`, `:tool`) and multi-modal content:

```elixir
# Text message
Message.user("Hello")

# Tool result
Message.tool_result("search", "call_123", [ContentPart.text("Results here")])
```

Content parts support `:text`, `:image` (binary data), and `:image_url`.

### Tool System (`tool.ex`, `tool_call.ex`, `tool_result.ex`)

Tools are pure data structures describing interfaces:

```elixir
Tool.new(
  name: "search",
  description: "Search the web",
  access: :read,
  parameter_schema: %{"query" => %{"type" => "string"}}
)
```

The loop's `execute_tools` callback accepts tool calls and a task supervisor. It builds descriptors and calls `ParallelExecutor.run/2` or `run_serial/2`.

Both return `{:ok, results}` in original call order. Serial execution waits for each result before dispatching the next call.

- `Sync` has a positive `timeout_ms`, a `run` MFA, and an `on_error` MFA.
- `Await` has a positive `timeout_ms` or `:infinity`, a `start` MFA, and an `on_error` MFA.
- The `run` and `start` MFAs receive one appended `tool_call` argument.
- The `on_error` MFA receives appended arguments `[reason, tool_call]`. The reason is `:timeout` or `{:crashed, exit_reason}`.
- The error callback returns the canonical `ToolResult` selected by application persistence. A stored success can win over a timeout or crash.
- A finite Sync deadline kills and monitors the task before the error callback runs. No late task return can replace that callback result.
- An infinite Await creates no timer. The executor waits for `{:tool_result, tool_call_id, content, is_error}` without polling.

Interactive human input is an explicit exception to bounded execution. The parked worker retains loop history in memory. It remains registered and cancellable.

Cancellation terminates the executor, not its existing Sync tasks under the runtime-global task supervisor. This pre-existing ownership limit is outside the timeout change.

### Telemetry (`telemetry.ex`, `telemetry/events.ex`)

Telemetry hierarchy:
```
[:swarm_ai, :run, :start/:stop/:exception]
└── [:swarm_ai, :step, :start/:stop/:exception]
    ├── [:swarm_ai, :llm, :call, :start/:stop/:exception]
    └── [:swarm_ai, :tool, :execute, :start/:stop/:exception]
```

---

## Execution Flow

1. **Entry**: `SwarmAi.run/2` starts supervised execution. `SwarmAi.Executor.run/2` calls `Loop.execute/1`.
2. **LLM Call**: `{:call_llm, ...}` effect triggers actual API call
3. **Response**: `Runner.handle_llm_response/2` produces effects based on tool calls
4. **Tool Execution**: `{:execute_tool, ...}` effects invoke the tool executor
5. **Continuation**: Tool results are added, next step starts with `{:call_llm, ...}`
6. **Completion**: `{:complete, result}` or `{:fail, error}` ends execution

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `executor.ex` | Runtime side-effect interpreter |
| `loop.ex` | Loop struct and state transitions |
| `loop/runner.ex` | Pure functional effect producer |
| `loop/step.ex` | Step data structure |
| `loop/config.ex` | Loop configuration defaults |
| `llm.ex` | LLM streaming protocol |
| `llm/response.ex` | Response aggregation from stream |
| `message.ex` | Message struct and factories |
| `message/content_part.ex` | Multi-modal content types |
| `tool.ex` | Tool definition struct |
| `tool_call.ex` | Tool invocation tracking |
| `tool_result.ex` | Tool execution result |
| `effect.ex` | Effect type definitions |
| `telemetry.ex` | Telemetry instrumentation |
| `id.ex` | UUIDv7-based ID generation |

---

## Configuration Defaults

From `loop/config.ex`:
- `max_steps`: 400
- `step_timeout_ms`: 60,000 (1 minute)
