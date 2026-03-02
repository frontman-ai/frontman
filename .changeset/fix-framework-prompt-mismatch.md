---
"@frontman/frontman-server-assets": patch
"@frontman-ai/frontman-core": patch
"@frontman-ai/nextjs": patch
"@frontman-ai/vite": patch
"@frontman-ai/astro": patch
"@frontman-ai/client": patch
---

Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.
