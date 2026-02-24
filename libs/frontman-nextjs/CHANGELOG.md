# @frontman-ai/nextjs

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
