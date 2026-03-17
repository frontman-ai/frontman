---
"@frontman-ai/frontman-protocol": minor
"@frontman-ai/frontman-client": minor
"@frontman-ai/client": minor
---

Add interactive question tool as a client-side MCP tool. Agents can ask users questions via a drawer UI with multi-step navigation, option selection, custom text input, and skip/cancel. Includes history replay ordering fixes (flush TextDeltaBuffer at message boundaries, use server timestamps for tool calls) and disconnect resilience: unresolved tool calls are re-dispatched on reconnect via MCP tools/call, tool results carry _meta with env API keys + model for agent resume after server restart, and persistence is moved to the SwarmAi runtime process (persist-then-broadcast) so data survives channel disconnects.
