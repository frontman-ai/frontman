# Swarm Architecture Specification

**Date**: 2026-01-14
**Git Commit**: 172d380c46578f5d36efccbb641e2869562b3439
**Branch**: main

---

## Summary

The `swarm/` directory implements a **functional core, imperative shell** architecture for executing AI agent loops. It orchestrates LLM interactions, tool execution, and parent-child agent spawning through a pure functional state machine that produces **effects** (instructions for side effects) which are interpreted by an impure execution layer.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Swarm Module (Impure Shell)                │
│   - Interprets effects                                              │
│   - Makes LLM API calls                                             │
│   - Executes tools                                                  │
│   - Spawns child agents                                             │
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

### 1. Agent Protocol (`agent.ex:1-61`)

Defines the contract for all agents via the `Swarm.Agent` protocol:

| Function | Purpose |
|----------|---------|
| `system_prompt/1` | Returns the system prompt string |
| `init/1` | Initializes agent state and returns tools |
| `should_terminate?/3` | Custom termination logic |
| `llm/1` | Returns the LLM client configuration |

Agents are structs that implement this protocol. Any struct can become an agent using `@derive Swarm.Agent`.

### 2. Loop State Machine (`loop.ex`, `loop/`)

The `Swarm.Loop` struct tracks execution state:

| Field | Purpose |
|-------|---------|
| `id` | UUIDv7-based unique identifier |
| `agent` | The agent being executed |
| `status` | `:ready`, `:running`, `:waiting_for_tools`, `:completed`, `:failed`, `:max_steps` |
| `steps` | History of all execution steps |
| `parent_id` | Parent loop ID for child agents |

**Status Transitions:**
```
:ready → :running → :waiting_for_tools → :running → ... → :completed
                                                       ↘ :failed
```

### 3. Runner (`loop/runner.ex`)

Pure functional module that produces effects without performing side effects:

```elixir
# Example: Starting a loop returns effects, not side effects
{loop, effects} = Runner.start(loop, messages)
# effects = [{:emit_event, Started}, {:call_llm, llm, messages}]
```

### 4. Effect System (`effect.ex`)

Effects are tagged tuples representing instructions:

| Effect | Action |
|--------|--------|
| `{:call_llm, llm, messages}` | Make an LLM API call |
| `{:execute_tool, tool_call}` | Execute a tool |
| `{:emit_event, event}` | Emit a domain event |
| `{:step_ended, step}` | A step completed |
| `{:complete, result}` | Loop finished successfully |
| `{:fail, error}` | Loop failed |

### 5. LLM Integration (`llm.ex`, `llm/`)

Protocol-based streaming interface:

```elixir
@spec stream(t, [Message.t()], keyword()) :: {:ok, Enumerable.t(Chunk.t())} | {:error, term()}
```

**Chunk Types**: `:token`, `:thinking`, `:tool_call_end`, `:usage`, `:done`

Production implementations should implement this protocol to support their preferred LLM providers.

### 6. Message System (`message.ex`, `message/`)

Messages have roles (`:system`, `:user`, `:assistant`, `:tool`) and multi-modal content:

```elixir
# Text message
Message.user("Hello")

# Tool result
Message.tool_result("search", "call_123", "Results here")
```

Content parts support `:text`, `:image` (binary data), and `:image_url`.

### 7. Tool System (`tool.ex`, `tool_call.ex`, `tool_result.ex`)

Tools are pure data structures describing interfaces:

```elixir
Tool.new("search", "Search the web", %{"query" => %{"type" => "string"}})
```

Tool execution is delegated to external executors:
```elixir
@type tool_executor :: (ToolCall.t() -> {:ok, String.t()} | {:error, String.t()} | {:spawn, SpawnChildAgent.t()})
```

### 8. Child Agent Spawning (`spawn_child_agent.ex`, `child_result.ex`)

Agents can spawn children by returning `{:spawn, SpawnChildAgent.t()}` from a tool executor:

```elixir
SpawnChildAgent.new(child_agent, "Analyze this deeply", max_steps: 10)
```

Child loops inherit metadata and track parent via `parent_id` and `parent_step` fields.

### 9. Events & Telemetry (`events.ex`, `telemetry.ex`, `telemetry/`)

Domain events: `Started`, `Completed`, `Failed`, `ToolCallRequested`

Telemetry hierarchy:
```
[:swarm, :run, :start/:stop/:exception]
└── [:swarm, :step, :start/:stop/:exception]
    ├── [:swarm, :llm, :call, :start/:stop/:exception]
    ├── [:swarm, :tool, :execute, :start/:stop/:exception]
    └── [:swarm, :child, :spawn, :start/:stop/:exception]
```

---

## Execution Flow

1. **Entry**: `Swarm.run_streaming/3` creates a loop and calls `Runner.start/2`
2. **LLM Call**: `{:call_llm, ...}` effect triggers actual API call
3. **Response**: `Runner.handle_llm_response/2` produces effects based on tool calls
4. **Tool Execution**: `{:execute_tool, ...}` effects invoke the tool executor
5. **Child Spawning**: If executor returns `{:spawn, ...}`, a child loop is created
6. **Continuation**: Tool results are added, next step starts with `{:call_llm, ...}`
7. **Completion**: `{:complete, result}` or `{:fail, error}` ends execution

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `agent.ex` | Agent protocol definition |
| `loop.ex` | Loop struct and state transitions |
| `loop/runner.ex` | Pure functional effect producer |
| `loop/step.ex` | Step data structure |
| `loop/config.ex` | Loop configuration defaults |
| `llm.ex` | LLM streaming protocol |
| `llm/chunk.ex` | Stream chunk types |
| `llm/response.ex` | Response aggregation from stream |
| `message.ex` | Message struct and factories |
| `message/content_part.ex` | Multi-modal content types |
| `tool.ex` | Tool definition struct |
| `tool_call.ex` | Tool invocation tracking |
| `tool_result.ex` | Tool execution result |
| `effect.ex` | Effect type definitions |
| `events.ex` | Domain event structs |
| `spawn_child_agent.ex` | Child agent spawn request |
| `child_result.ex` | Child execution result |
| `telemetry.ex` | Telemetry instrumentation |
| `id.ex` | UUIDv7-based ID generation |

---

## Configuration Defaults

From `loop/config.ex`:
- `max_steps`: 20
- `timeout_ms`: 300,000 (5 minutes)
- `step_timeout_ms`: 120,000 (2 minutes)
