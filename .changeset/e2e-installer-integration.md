---
"@frontman-ai/nextjs": patch
"@frontman-ai/vite": patch
---

E2E tests now run the Frontman installer CLI on bare fixture projects instead of using pre-wired configs, verifying that the installer produces working integrations for Next.js, Vite, and Astro.
