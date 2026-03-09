---
"swarm_ai": minor
---

Add tool suspension primitives to SwarmAi

- New `ToolResult.suspended/1` constructor for creating suspended tool results
- `ToolCall.completed?/1` returns false for suspended results; new `ToolCall.suspended?/1` predicate
- `Step.has_suspended_tools?/1` checks if any tool calls in a step are suspended
- `run_streaming/3` and `run_blocking/3` return `{:suspended, loop_id}` when a tool executor returns `:suspended`
- `Runtime.run/5` supports `on_suspended` lifecycle callback
