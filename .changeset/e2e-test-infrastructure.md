---
"@frontman-ai/nextjs": patch
"@frontman-ai/astro": patch
"@frontman-ai/vite": patch
---

Add Playwright + Vitest end-to-end test infrastructure with test suites for Next.js, Astro, and Vite. Tests validate the core product loop: open framework dev server, navigate to `/frontman`, log in, send a prompt, and verify the AI agent modifies source code.
