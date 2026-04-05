---
"@frontman-ai/client": minor
---

feat: add framework-conditional browser tool registration

Introduces `Client__ToolRegistry.forFramework` which composes core browser
tools with framework-specific tools based on the active runtime framework.
Creates `@frontman-ai/astro-browser` package as the first framework browser
tool package (empty for now — actual tools land in #782).
