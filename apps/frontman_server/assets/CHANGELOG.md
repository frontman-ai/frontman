# @frontman/frontman-server-assets

## 0.1.5

### Patch Changes

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

- [#497](https://github.com/frontman-ai/frontman/pull/497) [`32f87db`](https://github.com/frontman-ai/frontman/commit/32f87db122b4e60df36ebebeee918012734ad6b1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix gpt-5.3-codex custom LLMDB capabilities for OpenRouter and OpenAI providers. Tools, streaming tool_calls, and reasoning were incorrectly disabled, causing silent failures when the agent framework attempted tool calling with this model.

- [#471](https://github.com/frontman-ai/frontman/pull/471) [`732740c`](https://github.com/frontman-ai/frontman/commit/732740c3e8088c4b5ced77a00a4b2630d0876f62) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Refactor Agents module into Tasks.Execution with proper parent-child dependency injection via Context and Callbacks structs, eliminating bidirectional coupling between Tasks and Agents.

- [#482](https://github.com/frontman-ai/frontman/pull/482) [`604fe62`](https://github.com/frontman-ai/frontman/commit/604fe6291bbb696ae71aab0fd661a0e8fd7858fc) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Track all tool execution failures in Sentry. Adds error reporting for backend tool soft errors, MCP tool errors/timeouts, agent execution failures/crashes, and JSON argument parse failures. Normalizes backend tool result status from "error" to "failed" to fix client-side silent drop, and replaces silent catch-all in the client with a warning log for unexpected statuses.

- Updated dependencies [[`ed92762`](https://github.com/frontman-ai/frontman/commit/ed92762d46a3d26957eba8e68077398628e74f30), [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927)]:
  - @frontman-ai/frontman-client@0.3.2

## 0.1.4

### Patch Changes

- Updated dependencies [[`2d87685`](https://github.com/frontman-ai/frontman/commit/2d87685c436281dda18f5416782d9f6b9d85bc1c)]:
  - @frontman/frontman-client@0.3.1

## 0.1.3

### Patch Changes

- [#421](https://github.com/frontman-ai/frontman/pull/421) [`9e1ac77`](https://github.com/frontman-ai/frontman/commit/9e1ac77ec0f95a80dc1c831c3e811961564b97b4) Thanks [@itayadler](https://github.com/itayadler)! - Add Discord alerts for new user signups. A PostgreSQL AFTER INSERT trigger on the users table fires pg_notify, which a new Elixir GenServer listens to via Postgrex.Notifications and posts a rich embed to a Discord webhook. Enabled via DISCORD_NEW_USERS_WEBHOOK_URL env var.

## 0.1.2

### Patch Changes

- Updated dependencies [[`8a68462`](https://github.com/frontman-ai/frontman/commit/8a684623cde19966788d31fd1754d9dc94e0e031)]:
  - @frontman/frontman-client@0.3.0

## 0.1.1

### Patch Changes

- Updated dependencies [[`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248), [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248), [`b98bc4f`](https://github.com/frontman-ai/frontman/commit/b98bc4f2b2369dd6bc448f883b1a7dce3476b5ae)]:
  - @frontman/frontman-client@0.2.0
