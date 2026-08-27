---
"@frontman-ai/client": patch
"@frontman-ai/astro": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-core": patch
"@frontman-ai/nextjs": patch
"@frontman-ai/vite": patch
"@frontman-ai/frontman-wordpress": patch
---

Route client errors to the `SENTRY_DSN` configured by the host application instead of embedding Frontman's Sentry project in reusable packages.
