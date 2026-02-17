---
"@frontman-ai/astro": patch
"@frontman/client": patch
---

Fix source location detection for selected elements in Astro projects.

- Refactor Astro integration from Astro middleware to Vite Connect middleware for more reliable request interception
- Capture `data-astro-source-file`/`data-astro-source-loc` annotations on `DOMContentLoaded` before Astro's dev toolbar strips them
- Add ancestor walk fallback (up to 20 levels) so clicking child elements resolves to the nearest annotated Astro component
- Harden integration: `ensureConfig` guard for no-args usage, `duplex: 'half'` for POST requests, `headersSent` guard in error handler, skip duplicate capture on initial `astro:page-load`
- Add LLM error chunk propagation so API rejections (e.g., oversized images) surface to the client instead of silently failing
- Account for `devicePixelRatio` in screenshot scaling to avoid exceeding API dimension limits on hi-DPI displays
