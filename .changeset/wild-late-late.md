---
"frontman_server": minor
"swarm_ai": minor
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-protocol": patch
---

Replace suspension/resume with blocking interactive tools, fix agent message loss on session reload

- Interactive tools (e.g. question) block with a 2-minute receive timeout instead of suspending the agent
- Remove ResumeContext, ETS suspension state, on_suspended callback, resume_execution
- Simplify add_tool_result to return {:ok, interaction} directly (no resume signals)
- Pass mcp_tool_defs through for execution mode lookups (interactive vs synchronous timeout)
- Fix race condition: flush TextDeltaBuffer before LoadComplete to prevent agent messages from being silently dropped during history replay
- Thread server timestamps through agent_message_chunk for correct message ordering
- Add timestamp to agent_message_chunk in ACP protocol schema
