---
"@frontman-ai/client": patch
"@frontman-ai/nextjs": patch
---

### Fixed
- **Infinite reload loop with locale-based URL rewriting middleware** — four root causes fixed for apps using locale middleware (e.g. `next-intl`, `@formatjs/intl`):
  - `stripSuffix` unconditionally appended a trailing slash to every path even without a `/frontman` suffix, causing false-positive navigate intercepts. A new `hasSuffix` predicate now gates the intercept correctly.
  - Server-side redirects (e.g. `/en/` → `/en`) fire a `navigate` event before `onLoad`, causing a trailing-slash difference in the `url` prop to reload the iframe while `hasLoaded` was still `false`. The url-prop effect now normalizes trailing slashes before comparing.
  - Session restore mounted all persisted task iframes eagerly (20+ concurrent requests). Inactive iframes now start with `src=""` and load lazily on first activation.
  - The generated `proxy.ts` (Next.js ≥16) used a path guard that missed `/en/frontman/` (the trailing-slash URL written by `syncBrowserUrl`). The template now delegates directly to the core middleware via `await frontman(req)`, matching the `middleware.ts` pattern. The `/:path*/frontman/` matcher is also added to all generated configs.
