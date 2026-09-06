# SwarmAi

[![Hex.pm](https://img.shields.io/hexpm/v/swarm_ai.svg)](https://hex.pm/packages/swarm_ai)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/swarm_ai)

SwarmAi runs supervised AI loops in Elixir. A pure state machine produces effects. The executor handles LLM calls and tool execution.

## Installation

Add the published package to `mix.exs`:

```elixir
{:swarm_ai, "~> 1.0"}
```

The examples below describe the unreleased source API. The timeout changes break compatibility with previous releases. See [CHANGELOG.md](CHANGELOG.md).

## Quick Start

Add a runtime to the supervision tree:

```elixir
children = [{SwarmAi, name: MyApp.AgentRuntime}]
```

Create a loop with complete input messages, an LLM client, a tool callback, and an event callback:

```elixir
loop = SwarmAi.Loop.new(%{
  task_id: task_id,
  turn_number: 1,
  messages: [SwarmAi.Message.user("Analyze this code")],
  llm: MyLLMClient.new("my-model"),
  execute_tools: &MyTools.execute/2,
  dispatch_event: &MyEvents.dispatch/1
})

{:ok, pid} = SwarmAi.run(MyApp.AgentRuntime, loop)
SwarmAi.running?(MyApp.AgentRuntime, loop.task_id)
SwarmAi.cancel(MyApp.AgentRuntime, loop.task_id)
```

The LLM client implements `SwarmAi.LLM.stream/3`. The tool callback accepts tool calls and a task supervisor. It returns `{:ok, results}`.

## Tool Execution

`SwarmAi.Tool` contains only the name, description, access mode, and parameter schema for the LLM. Execution descriptors own deadlines and error callbacks.

```elixir
%SwarmAi.ToolExecution.Await{
  tool_call: tool_call,
  timeout_ms: :infinity,
  start: {MyTools, :request_answer, [context]},
  on_error: {MyTools, :persist_error, [context]}
}
```

The `start` MFA receives one appended argument: `tool_call`. This callback runs in the executor process. It registers delivery before publishing the request.

The answer arrives as `{:tool_result, tool_call_id, content, is_error}`. With `:infinity`, no timer exists and the error callback does not run for a deadline.

The `on_error` MFA receives two appended arguments: `reason` and `tool_call`. The reason is `:timeout` or `{:crashed, exit_reason}`.

The error callback returns the canonical `SwarmAi.ToolResult` selected by application persistence. It does not return `:ok`. A stored success can win over a timeout or crash.

`Sync` descriptors require a positive millisecond deadline and a `run` MFA. The executor kills and monitors the timed-out Sync task before the error callback runs.

`ParallelExecutor.run/2` returns results in call order. `run_serial/2` also preserves dispatch order. An interactive wait blocks subsequent serial calls, but not parallel siblings.

Human waits are an explicit exception to bounded execution. A parked executor retains its history in memory without polling or calling the LLM.

Cancellation terminates the parked executor and removes its registration. Existing Sync tasks use the runtime-global task supervisor and can outlive executor cancellation. This release does not change that ownership.

## Telemetry

| Event | Scope |
|-------|-------|
| `[:swarm_ai, :run, :start\|:stop\|:exception]` | Loop execution |
| `[:swarm_ai, :step, :start\|:stop]` | One LLM step |
| `[:swarm_ai, :llm, :call, :start\|:stop\|:exception]` | LLM call |
| `[:swarm_ai, :tool, :execute, :start\|:stop\|:exception]` | Tool execution |

## License

Apache-2.0. See [LICENSE](LICENSE).
