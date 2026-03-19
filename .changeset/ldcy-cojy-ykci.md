---
"@frontman-ai/client": patch
"@frontman-ai/frontman-core": patch
"@frontman-ai/nextjs": patch
"@frontman-ai/vite": patch
"@frontman-ai/react-statestore": patch
---

Minor improvements: tree navigation for annotation markers, stderr log capture fix, and publish guard for npm packages

- Add parent/child tree navigation controls to annotation markers in the web preview
- Fix log capture to intercept process.stderr in addition to process.stdout (captures Astro [ERROR] messages)
- Add duplicate-publish guard to `make publish` in nextjs, vite, and react-statestore packages
