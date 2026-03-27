---
description: Debug Frontman task interactions from the database
---

You are debugging task interactions stored in the Frontman server database.

The `mix debug_task` Mix task (in `apps/frontman_server`) queries the `tasks` and `interactions` tables and prints a formatted summary. It is wrapped by a Makefile target for convenience.

## Available commands

Run these via `make` from the `apps/frontman_server` directory:

```
# List recent tasks with error counts
make debug-task ARGS="list"

# Show all interactions for the most recent task
make debug-task

# Show only errors (failed tool results)
make debug-task ARGS="show --errors"

# Filter by tool name
make debug-task ARGS="show --tool edit_file"

# Filter by interaction type (user_message, agent_response, tool_call, tool_result, agent_spawned, agent_completed)
make debug-task ARGS="show --type tool_call"

# Show full detail for a specific interaction by sequence number
make debug-task ARGS="show --seq 280"

# Show a specific task by ID prefix
make debug-task ARGS="show c5f3"

# Combine filters
make debug-task ARGS="show --tool edit_file --errors"
```

## Workflow

Based on the user's request (`$ARGUMENTS`), follow this process:

1. **Start with context** - If no specific task is mentioned, first list recent tasks by running:
   ```bash
   cd apps/frontman_server && make debug-task ARGS="list --limit 5"
   ```

2. **Narrow down** - Based on what the user asked for, run the appropriate filtered command. Common patterns:
   - "what went wrong" / "errors" -> `make debug-task ARGS="show --errors"`
   - "what happened with edit_file" -> `make debug-task ARGS="show --tool edit_file"`
   - "show me the tool calls" -> `make debug-task ARGS="show --type tool_call"`
   - "show me interaction 280" -> `make debug-task ARGS="show --seq 280"`

3. **Drill into detail** - When you find an interesting interaction, use `--seq NUMBER` to get the full JSON data. For failed tool results, this automatically shows the originating tool call.

4. **Analyze and explain** - After fetching the data, explain what happened in plain language:
   - What the agent was trying to do
   - What went wrong (for errors)
   - The sequence of events leading up to the issue
   - Suggestions for what might fix it

## Notes

- All commands run from `apps/frontman_server` via `make debug-task ARGS="..."`
- The Makefile target handles 1Password secret injection automatically
- Sequence numbers are monotonic - higher = later in the conversation
- Interaction types: `user_message`, `agent_response`, `tool_call`, `tool_result`, `agent_spawned`, `agent_completed`, `discovered_project_rule`
- `tool_result` with `is_error=true` indicates a failed tool execution
- The `--seq` detail view for errors automatically includes the originating `tool_call`
