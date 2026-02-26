# @frontman/frontman-server-assets

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
