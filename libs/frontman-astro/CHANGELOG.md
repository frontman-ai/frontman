# @frontman-ai/astro

## 0.1.5

### Patch Changes

- [#379](https://github.com/frontman-ai/frontman/pull/379) [`68b7f53`](https://github.com/frontman-ai/frontman/commit/68b7f53d10c82fe5b462021cc2e866c0822fa0d8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix source location detection for selected elements in Astro projects.
  - Refactor Astro integration from Astro middleware to Vite Connect middleware for more reliable request interception
  - Capture `data-astro-source-file`/`data-astro-source-loc` annotations on `DOMContentLoaded` before Astro's dev toolbar strips them
  - Add ancestor walk fallback (up to 20 levels) so clicking child elements resolves to the nearest annotated Astro component
  - Harden integration: `ensureConfig` guard for no-args usage, `duplex: 'half'` for POST requests, `headersSent` guard in error handler, skip duplicate capture on initial `astro:page-load`
  - Add LLM error chunk propagation so API rejections (e.g., oversized images) surface to the client instead of silently failing
  - Account for `devicePixelRatio` in screenshot scaling to avoid exceeding API dimension limits on hi-DPI displays

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix missing `host` param in Astro config that caused the client to crash on boot. Both Astro and Next.js configs now assert at construction time that `clientUrl` contains the required `host` query param, using the URL API for proper query-string handling.
