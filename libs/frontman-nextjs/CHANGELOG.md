# @frontman-ai/nextjs

## 0.6.2

### Patch Changes

- [#567](https://github.com/frontman-ai/frontman/pull/567) [`331d899`](https://github.com/frontman-ai/frontman/commit/331d899bfdf69d370fe810ac0d0f0f941f661b76) Thanks [@itayadler](https://github.com/itayadler)! - Fix Next.js installer failing in monorepo setups where node_modules are hoisted
  - Use Node.js `createRequire` for module resolution instead of a hardcoded `node_modules/next/package.json` path
  - Add `hasNextDependency` check to prevent false detection in sibling workspaces
  - Remove E2E symlink workaround that was papering over the root cause

- [#608](https://github.com/frontman-ai/frontman/pull/608) [`48e688a`](https://github.com/frontman-ai/frontman/commit/48e688a73f5b4a8ecb5e6d6860cd767a7f8fcd77) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - ### Fixed
  - **Infinite reload loop with locale-based URL rewriting middleware** — four root causes fixed for apps using locale middleware (e.g. `next-intl`, `@formatjs/intl`):
    - `stripSuffix` unconditionally appended a trailing slash to every path even without a `/frontman` suffix, causing false-positive navigate intercepts. A new `hasSuffix` predicate now gates the intercept correctly.
    - Server-side redirects (e.g. `/en/` → `/en`) fire a `navigate` event before `onLoad`, causing a trailing-slash difference in the `url` prop to reload the iframe while `hasLoaded` was still `false`. The url-prop effect now normalizes trailing slashes before comparing.
    - Session restore mounted all persisted task iframes eagerly (20+ concurrent requests). Inactive iframes now start with `src=""` and load lazily on first activation.
    - The generated `proxy.ts` (Next.js ≥16) used a path guard that missed `/en/frontman/` (the trailing-slash URL written by `syncBrowserUrl`). The template now delegates directly to the core middleware via `await frontman(req)`, matching the `middleware.ts` pattern. The `/:path*/frontman/` matcher is also added to all generated configs.

## 0.6.0

### Minor Changes

- [#496](https://github.com/frontman-ai/frontman/pull/496) [`4641751`](https://github.com/frontman-ai/frontman/commit/46417511374ef0d69f8b8ac94defa1eabd279044) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show in-browser banner when a newer integration package is available. Integration packages now report their real version (instead of hardcoded "1.0.0"), the server proxies npm registry lookups with a 30-minute cache, and the client displays a dismissible amber banner with an "Update" button that prompts the LLM to perform the upgrade.

### Patch Changes

- [#457](https://github.com/frontman-ai/frontman/pull/457) [`bbd6900`](https://github.com/frontman-ai/frontman/commit/bbd6900c35c7a22e4773faa24a04357ee479f793) Thanks [@itayadler](https://github.com/itayadler)! - E2E tests now run the Frontman installer CLI on bare fixture projects instead of using pre-wired configs, verifying that the installer produces working integrations for Next.js, Vite, and Astro.

- [#438](https://github.com/frontman-ai/frontman/pull/438) [`1648416`](https://github.com/frontman-ai/frontman/commit/164841645854156c646acb350821c92fbfa11354) Thanks [@itayadler](https://github.com/itayadler)! - Add Playwright + Vitest end-to-end test infrastructure with test suites for Next.js, Astro, and Vite. Tests validate the core product loop: open framework dev server, navigate to `/frontman`, log in, send a prompt, and verify the AI agent modifies source code.

- [#455](https://github.com/frontman-ai/frontman/pull/455) [`ed92762`](https://github.com/frontman-ai/frontman/commit/ed92762d46a3d26957eba8e68077398628e74f30) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Filter third-party errors from Frontman's internal Sentry reporting. Extracts shared Sentry types, config (DSN, internal-dev detection), and a `beforeSend` filter into `@frontman/bindings` so all framework integrations share a single source of truth. The filter inspects stacktrace frames and drops events that don't originate from Frontman code, preventing noise from framework internals (e.g. Next.js/Turbopack source-map WASM fetch failures). Both `@frontman-ai/nextjs` and `@frontman-ai/frontman-client` now use this shared filter.

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

## 0.5.2

### Patch Changes

- [#452](https://github.com/frontman-ai/frontman/pull/452) [`2d87685`](https://github.com/frontman-ai/frontman/commit/2d87685c436281dda18f5416782d9f6b9d85bc1c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix 8 Dependabot security alerts by upgrading Sentry SDK from v8 to v9, sentry-testkit to v6, and adding yarn resolutions for vulnerable transitive dependencies (rollup, basic-ftp, minimatch, devalue, hono).

## 0.5.0

### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

## 0.4.0

### Minor Changes

- [#398](https://github.com/frontman-ai/frontman/pull/398) [`8269bb4`](https://github.com/frontman-ai/frontman/commit/8269bb448c555420326f035f6f17b7eb2f69033b) Thanks [@itayadler](https://github.com/itayadler)! - Add `edit_file` tool with 9-strategy fuzzy text matching for robust LLM-driven file edits. Framework-specific wrappers (Vite, Astro, Next.js) check dev server logs for compilation errors after edits. Add `get_logs` tool to Vite and Astro for querying captured console/build output.

- [#418](https://github.com/frontman-ai/frontman/pull/418) [`930669c`](https://github.com/frontman-ai/frontman/commit/930669c179b02b79ae35af662479914746638754) Thanks [@itayadler](https://github.com/itayadler)! - Extract shared middleware (CORS, UI shell, request handlers, SSE streaming) into frontman-core, refactor Astro/Next.js/Vite adapters to thin wrappers

- [#415](https://github.com/frontman-ai/frontman/pull/415) [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df) Thanks [@itayadler](https://github.com/itayadler)! - Add Lighthouse tool for web performance auditing. The `lighthouse` tool runs Google Lighthouse audits on URLs and returns scores (0-100) for performance, accessibility, best practices, and SEO categories, along with the top 3 issues to fix in each category. In DevPod environments, URLs are automatically rewritten to localhost to avoid TLS/interstitial issues. The Next.js config now falls back to PHX_HOST for automatic host detection in DevPod setups.

## 0.3.0

### Minor Changes

- [#335](https://github.com/frontman-ai/frontman/pull/335) [`389fff7`](https://github.com/frontman-ai/frontman/commit/389fff728ccbeaf6d73ca80497f1b8b4bd7c6c63) Thanks [@itayadler](https://github.com/itayadler)! - Add AI-powered auto-edit for existing files during `npx @frontman-ai/nextjs install` and colorized CLI output with brand purple theme.
  - When existing middleware/proxy/instrumentation files are detected, the installer now offers to automatically merge Frontman using an LLM (OpenCode Zen, free, no API key)
  - Model fallback chain (gpt-5-nano → big-pickle → grok-code) with output validation
  - Privacy disclosure: users are informed before file contents are sent to a public LLM
  - Colorized terminal output: purple banner, green checkmarks, yellow warnings, structured manual instructions
  - Fixed duplicate manual instructions in partial-success output

### Patch Changes

- [#337](https://github.com/frontman-ai/frontman/pull/337) [`7e4386f`](https://github.com/frontman-ai/frontman/commit/7e4386fc5fdeea349efa61de97ed119f99f9585a) Thanks [@itayadler](https://github.com/itayadler)! - Move installer to npx-only, remove curl|bash endpoint, make --server optional
  - Remove API server install endpoint (InstallController + /install routes)
  - Make `--server` optional with default `api.frontman.sh`
  - Simplify Readline.res: remove /dev/tty hacks, just use process.stdin
  - Add `config.matcher` to proxy.ts template and auto-edit LLM rules
  - Update marketing site install command from curl to `npx @frontman-ai/nextjs install`
  - Update README install instructions

- [#336](https://github.com/frontman-ai/frontman/pull/336) [`b98bc4f`](https://github.com/frontman-ai/frontman/commit/b98bc4f2b2369dd6bc448f883b1a7dce3476b5ae) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Suppress Sentry error reporting during Frontman internal development via FRONTMAN_INTERNAL_DEV env var

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix missing `host` param in Astro config that caused the client to crash on boot. Both Astro and Next.js configs now assert at construction time that `clientUrl` contains the required `host` query param, using the URL API for proper query-string handling.
