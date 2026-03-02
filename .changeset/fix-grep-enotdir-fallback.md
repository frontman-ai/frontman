---
"@frontman-ai/frontman-core": patch
---

Fix ENOTDIR crash in grep tool when LLM passes a file path. Harden all search tools (grep, search_files, list_files, list_tree) to gracefully handle file paths instead of crashing. Catch synchronous spawn() throws in spawnPromise so errors flow through the result type. Rewrite tool descriptions for clarity and remove duplicated tool selection guidance from system prompt.
