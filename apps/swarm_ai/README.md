# SwarmAi

[![Hex.pm](https://img.shields.io/hexpm/v/swarm_ai.svg)](https://hex.pm/packages/swarm_ai)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/swarm_ai)

A functional AI agent execution framework for Elixir with protocol-based LLM and tool integration.

SwarmAi implements a **functional core / imperative shell** architecture: a pure state machine produces effects (instructions for side effects) which are interpreted by an execution layer. This makes agent logic deterministic and testable while keeping I/O at the edges.

## Installation

Add `swarm_ai` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:swarm_ai, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Define an Agent

Agents are structs that implement the `SwarmAi.Agent` protocol:

```elixir
defmodule MyAgent do
  use TypedStruct

  typedstruct do
    field :model, String.t(), default: "gpt-4o"
  end

  defimpl SwarmAi.Agent do
    def system_prompt(_agent), do: "You are a helpful assistant."
    def init(_agent), do: {:ok, %{}, []}
    def should_terminate?(_agent, _loop, _response), do: false
    def llm(agent), do: MyLLMClient.new(agent.model)
  end
end
```

### Blocking Execution

```elixir
agent = %MyAgent{}

{:ok, result, loop_id} = SwarmAi.run_blocking(agent, "Hello!", fn tool_call ->
  case tool_call.name do
    "search" -> {:ok, "search results here"}
    _ -> {:error, "unknown tool"}
  end
end)
```

### Streaming Execution

```elixir
{:ok, result, loop_id} = SwarmAi.run_streaming(agent, "Analyze this code",
  tool_executor: &execute_tool/1,
  on_chunk: fn chunk -> IO.write(chunk.text || "") end,
  on_response: fn response -> Logger.info("Response complete") end,
  on_tool_call: fn tc -> Logger.info("Calling #{tc.name}") end
)
```

### Manual Control

For fine-grained control over tool execution:

```elixir
case SwarmAi.run(agent, "What's the weather?") do
  {:completed, loop} ->
    loop.result

  {:tool_calls, loop, tool_calls} ->
    results = Enum.map(tool_calls, &execute_tool/1)
    SwarmAi.continue(loop, results)

  {:error, loop} ->
    {:error, loop.error}
end
```

## Architecture

```
┌──────────────────────────────────────────────────┐
│            SwarmAi Module (Impure Shell)          │
│  Interprets effects, makes LLM calls,            │
│  executes tools, spawns child agents              │
└────────────────────────┬─────────────────────────┘
                         │ produces/consumes
                         ▼
┌──────────────────────────────────────────────────┐
│        Loop + Runner (Pure Functional Core)       │
│  State machine for agent execution,               │
│  returns {loop, effects} tuples, no side effects  │
└──────────────────────────────────────────────────┘
```

### Key Concepts

- **Agent Protocol** - Define agents as structs implementing `SwarmAi.Agent` (system prompt, tools, LLM config, termination logic)
- **LLM Protocol** - Bring your own LLM client by implementing `SwarmAi.LLM` (streaming interface)
- **Effect System** - Pure functions produce effects (`{:call_llm, ...}`, `{:execute_tool, ...}`) instead of performing I/O directly
- **Tool Execution** - Tools are pure data structures; execution is delegated to your `tool_executor` function
- **Child Agents** - Tools can spawn sub-agents by returning `{:spawn, SpawnChildAgent.t()}`
- **Telemetry** - Built-in `:telemetry` events for runs, steps, LLM calls, tool executions, and child spawns

## Telemetry Events

SwarmAi emits telemetry under the `[:swarm_ai, ...]` prefix:

| Event | Description |
|-------|-------------|
| `[:swarm_ai, :run, :start\|:stop\|:exception]` | Full agent run lifecycle |
| `[:swarm_ai, :step, :start\|:stop]` | Individual step within a run |
| `[:swarm_ai, :llm, :call, :start\|:stop\|:exception]` | LLM API calls |
| `[:swarm_ai, :tool, :execute, :start\|:stop\|:exception]` | Tool executions |
| `[:swarm_ai, :child, :spawn, :start\|:stop\|:exception]` | Child agent spawns |

## License

Apache-2.0 - see the LICENSE file for details.
