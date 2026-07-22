---
"@frontman-ai/nextjs": patch
---

Fix Next.js CLI entrypoint detection so projects with a root router and unrelated src directory keep middleware or proxy files at the repository root.
