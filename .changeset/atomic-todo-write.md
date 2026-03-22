---
"@frontman-ai/client": patch
---

Replace 4 incremental todo tools (todo_add, todo_update, todo_remove, todo_list) with a single atomic `todo_write` tool. The LLM now sends the complete todo list every call, eliminating hallucinated IDs, duplicate entries, and state drift between turns. Adds priority field (high/medium/low) to todos.
