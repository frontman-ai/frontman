---
"@frontman-ai/frontman-server": patch
"@frontman-ai/client": patch
---

### Fixed
- Stream `tool_call_start` events to client for immediate UI feedback when the LLM begins generating tool calls (e.g., `write_file`), eliminating multi-second blank gaps
- Show "Waiting for file path..." / "Waiting for URL..." shimmer placeholder while tool arguments stream in
- Display navigate tool URL/action inline instead of hiding it in an expandable body
