---
"@frontman-ai/client": minor
---

Add the `fill` action to browser element interactions. Agents can replace or clear text in inputs, textareas, and contenteditable editing hosts. Discovery and filling share the same host check. Fill rejects editable descendants that are not editing hosts. The tool uses editor-supported paste/delete events for controlled contenteditable fields. It checks field content after editing and reports rejected interactions through the shared structured MCP error result, with matching text and structured content. A successful fill does not prove that the application saved the value.
