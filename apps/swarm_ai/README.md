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

### Define an Agent and Run

Agents own lifecycle identity and execution data. `id/1` must return a stable string.

```elixir
defmodule MyAgent do
  defstruct [:id, :messages, :tool_executor, context: %{}, model: "gpt-4o"]

  defimpl SwarmAi.Agent do
    def id(%{id: id}) when is_binary(id), do: id
    def messages(agent), do: agent.messages
    def context(agent), do: agent.context
    def tool_executor(agent), do: agent.tool_executor
    def system_prompt(_agent), do: "You are a helpful assistant."
    def llm(agent), do: MyLLMClient.new(agent.model)
  end
end
```

### Supervised Execution

```elixir
children = [
  {SwarmAi,
   name: MyApp.AgentRuntime,
   event_dispatcher: {MyApp.SwarmDispatcher, :dispatch, []}}
]

agent = %MyAgent{
  id: task_id,
  messages: "Analyze this code",
  context: %{task_id: task_id},
  tool_executor: %{build: &build_tool_executions/1, execution_mode: :parallel}
}

{:ok, pid} = SwarmAi.run(MyApp.AgentRuntime, agent)

SwarmAi.running?(MyApp.AgentRuntime, SwarmAi.Agent.id(agent))
SwarmAi.cancel(MyApp.AgentRuntime, SwarmAi.Agent.id(agent))
```

## Architecture

```
┌──────────────────────────────────────────────────┐
│            SwarmAi Public API                     │
│  Supervised runs, cancellation, execution events  │
└────────────────────────┬─────────────────────────┘
                         │ produces/consumes
                         ▼
┌──────────────────────────────────────────────────┐
│        Executor + Loop (Functional Core)          │
│  State machine for agent execution,               │
│  returns {loop, effects} tuples, no side effects  │
└──────────────────────────────────────────────────┘
```

### Key Concepts

- **Agent Protocol** - Define stable string identity, messages, dispatcher context, tool executor, system prompt, and LLM config
- **LLM Protocol** - Bring your own LLM client by implementing `SwarmAi.LLM` (streaming interface)
- **Effect System** - Pure functions produce effects (`{:call_llm, ...}`, `{:execute_tool, ...}`) instead of performing I/O directly
- **Tool Execution** - Tools are pure data structures; execution is delegated to the agent's `tool_executor`
- **Telemetry** - Built-in `:telemetry` events for runs, steps, LLM calls, and tool executions

## Telemetry Events

SwarmAi emits telemetry under the `[:swarm_ai, ...]` prefix:

| Event | Description |
|-------|-------------|
| `[:swarm_ai, :run, :start\|:stop\|:exception]` | Full agent run lifecycle |
| `[:swarm_ai, :step, :start\|:stop]` | Individual step within a run |
| `[:swarm_ai, :llm, :call, :start\|:stop\|:exception]` | LLM API calls |
| `[:swarm_ai, :tool, :execute, :start\|:stop\|:exception]` | Tool executions |

## License

Apache-2.0 - see the LICENSE file for details.
