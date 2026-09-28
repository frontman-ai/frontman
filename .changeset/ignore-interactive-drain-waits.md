---
---

Exclude executions waiting only for interactive tool answers from the deployment drain count. Continue counting finite tool work and resumed executions. Keep shutdown, cancellation, and question recovery unchanged.

Move tool scheduling and wait tracking into Swarm. Loop callers now supply `prepare_tools(tool_calls)`, returning a scheduling mode and execution descriptors, instead of executing tools themselves.
