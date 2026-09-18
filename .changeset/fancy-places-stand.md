---
"@frontman-ai/astro": patch
"@frontman-ai/vite": patch
"@frontman-ai/nextjs": patch
"@frontman-ai/frontman-wordpress": patch
"@frontman-ai/client": patch
---

Install the preview bridge for Astro, Vite, Next.js and WordPress. Preserve each frame's configuration across reloads and navigation without changing application URLs. Add the loader to existing Next.js installations on reinstall.

Restrict preview bridge connections to parents on the preview page's own origin. Cross-origin previews are not supported.

Consolidate client task state while preserving task identity, history replay, preview references, and lifecycle validation. Simplify regression tests by sharing fixtures and repeated setup without removing behavioral checks.
