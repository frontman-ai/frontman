---
"@frontman-ai/nextjs": minor
---

Add AI-powered auto-edit for existing files during `npx @frontman-ai/nextjs install` and colorized CLI output with brand purple theme.

- When existing middleware/proxy/instrumentation files are detected, the installer now offers to automatically merge Frontman using an LLM (OpenCode Zen, free, no API key)
- Model fallback chain (gpt-5-nano → big-pickle → grok-code) with output validation
- Privacy disclosure: users are informed before file contents are sent to a public LLM
- Colorized terminal output: purple banner, green checkmarks, yellow warnings, structured manual instructions
- Fixed duplicate manual instructions in partial-success output
