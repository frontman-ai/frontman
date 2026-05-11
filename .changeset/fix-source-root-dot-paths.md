---
"@frontman-ai/frontman-core": patch
"@frontman-ai/vite": patch
---

Fix path validation when Vite reports `sourceRoot: "."` so normal project-relative paths like `src/main.tsx` can be read and edited.
