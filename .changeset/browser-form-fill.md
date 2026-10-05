---
"@frontman-ai/client": minor
---

Add the `fill` action to browser element interactions. Agents can replace or clear text in inputs, textareas, and contenteditable fields. The tool uses editor-supported paste/delete events for controlled contenteditable fields. It checks field content after editing and reports rejected interactions as MCP errors. A successful fill does not prove that the application saved the value.
