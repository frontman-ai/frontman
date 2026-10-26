# @frontman/frontman-server-assets

## 0.2.1

### Patch Changes

- [#1986](https://github.com/frontman-ai/frontman/pull/1986) [`1f7f45f`](https://github.com/frontman-ai/frontman/commit/1f7f45fca856fb0e629f0223c5aa7ae8602336c3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Bind OAuth sign-in and account linking to browser state, consume matching callbacks once, and return controlled errors for rejected linking and unsupported or absent provider connections.
- Updated dependencies [[`db72760`](https://github.com/frontman-ai/frontman/commit/db72760b282b87d4c20b72a1527ef3be58e99c05), [`a21ed02`](https://github.com/frontman-ai/frontman/commit/a21ed02aa8c72b395586203c28e96e86dba95780), [`51c42f6`](https://github.com/frontman-ai/frontman/commit/51c42f60bfeccf92ab30866fd6d914b084e5dc7e)]:
  - @frontman-ai/frontman-client@4.0.5

## 0.2.0

### Minor Changes

- [#1807](https://github.com/frontman-ai/frontman/pull/1807) [`86327f3`](https://github.com/frontman-ai/frontman/commit/86327f316ece79a293277172bbc6a88729c8a590) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Allow five AI runs before a Frontman trial is required. Users must connect their own AI provider; provider access is validated before a turn is claimed for both subscribers and allowance users. The allowance is shared across projects and does not reset when conversations are deleted. Claimed turns can retry and recover without another charge, even after subscription access ends. Pre-turn failures do not offer turn retry; saving provider credentials resumes queued work. Billing status now exposes `can_start_turn` instead of `access_allowed` to distinguish new-turn eligibility from continuation.

### Patch Changes

- [#1880](https://github.com/frontman-ai/frontman/pull/1880) [`582dda1`](https://github.com/frontman-ai/frontman/commit/582dda13c9292800e6c03e1125d8f3d7c7f823ff) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Block new usage as soon as Stripe reports a past-due subscription after a failed payment, rather than allowing access during payment retries. Restore access when the subscription becomes active again. Prevent duplicate subscription checkout for past-due users and direct them to manage payment in Stripe.

- [#1897](https://github.com/frontman-ai/frontman/pull/1897) [`c7261a7`](https://github.com/frontman-ai/frontman/commit/c7261a75f63ed33c7f33ee0590409e5ad250118a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reject MCP tool schemas with map or array containers more than 64 edges below the root before runtime compilation. Previously accepted deeper schemas now fail validation; scalar leaves at depth 65 remain allowed.

- [#1912](https://github.com/frontman-ai/frontman/pull/1912) [`53afe76`](https://github.com/frontman-ai/frontman/commit/53afe7616fe328e1675c5c17d05bca79afe03a3a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reject MCP tool schemas with more than 10,000 JSON nodes before runtime compilation. Previously accepted larger schemas now fail validation. Each schema has its own budget; object keys do not count.

- [#1889](https://github.com/frontman-ai/frontman/pull/1889) [`188c60d`](https://github.com/frontman-ai/frontman/commit/188c60d6d1c37d88542a64508fa76abd407f8153) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add nullable UTC-second first-message observation storage without a default, backfill, index, or writer. Registration input cannot set it. A missing timestamp does not establish observation coverage.

  Deploy the migration before the new binary; old binaries can coexist with the added column. Retain the column and values on application rollback; do not use the schema down-migration for routine rollback.

- [#1895](https://github.com/frontman-ai/frontman/pull/1895) [`2a039ca`](https://github.com/frontman-ai/frontman/commit/2a039ca89dfd1d84146ef0470ebdb3485761d5b6) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Record the first accepted prompt atomically and retain it after message or task deletion.

- [#1890](https://github.com/frontman-ai/frontman/pull/1890) [`8d7aa86`](https://github.com/frontman-ai/frontman/commit/8d7aa86b110e5854a0b0d8c290ac7bc7f9c62e3e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Stop explicitly subscribing contacts during Resend contact sync. Repeated requests omit subscription preferences; provider preservation on duplicate creation remains unverified. Old workers and rollback versions can still write subscription preferences until drained.

- [#1896](https://github.com/frontman-ai/frontman/pull/1896) [`06b9440`](https://github.com/frontman-ai/frontman/commit/06b94404fbc7008a5dfecf9505ee5b1c3e286262) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add a fresh scoped activation-candidate check with an inclusive UTC signup age bound, not send authorization. Backfill existing users with the migration timestamp so they do not receive activation emails; preserve recorded first-prompt timestamps.

- [#1891](https://github.com/frontman-ai/frontman/pull/1891) [`05bb541`](https://github.com/frontman-ai/frontman/commit/05bb54129ec266c76ce4150a355932e90a8ba8c2) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Cover OAuth signup, email verification, repeat login, and identity linking through HTTP routes, with local WorkOS responses and persisted account, session, and job assertions.

- [#1837](https://github.com/frontman-ai/frontman/pull/1837) [`d284554`](https://github.com/frontman-ai/frontman/commit/d2845543589542ca366ad102d50024ba229e81d6) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Store customer feedback requests and immutable scores in a dedicated context with a per-user rolling 30-day cooldown.

- [#1913](https://github.com/frontman-ai/frontman/pull/1913) [`9ec6dad`](https://github.com/frontman-ai/frontman/commit/9ec6dadae5313f7a26e5ff050ef9f0d0e6bdd974) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Refresh the model picker with GPT-6.1 Sol, Claude Haiku 5.5, Gemini 4 Argon, and current OpenRouter, Fireworks, and NVIDIA models. Update model metadata and documentation. Remove retired GPT-5.5 from Codex sign-in and retired Claude Opus 4 and Sonnet 4 from Anthropic.

- [#1881](https://github.com/frontman-ai/frontman/pull/1881) [`5028992`](https://github.com/frontman-ai/frontman/commit/50289929c765f321a7d821ac53bbeb82e72441f3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Offer a 7-day free Pro trial with a card. Keep five free uses without a card. Unused free uses stay available. Existing trial dates stay unchanged.

- [#1843](https://github.com/frontman-ai/frontman/pull/1843) [`0bfca4e`](https://github.com/frontman-ai/frontman/commit/0bfca4ed2e7cc8bcf7e3bb87e51b277322d000a8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enable optional customer feedback in WordPress, Astro, Next.js, and Vite through the existing question interaction. Store ratings and skips as ordinary MCP tool results instead of duplicating feedback persistence. Drop the unused customer feedback table and its data. Apply the 30-day cooldown using the user's stored feedback tool interactions. Keep feedback guidance in the tool description.

- [#1892](https://github.com/frontman-ai/frontman/pull/1892) [`2a6995b`](https://github.com/frontman-ai/frontman/commit/2a6995b5d1c0c579c9fc7bc729ffdb52f4462276) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add a pure first-follow-up email builder without sending or scheduling emails.
- Updated dependencies [[`3e527dc`](https://github.com/frontman-ai/frontman/commit/3e527dc7ec76333f9886926eec02b8de974927ef), [`3e527dc`](https://github.com/frontman-ai/frontman/commit/3e527dc7ec76333f9886926eec02b8de974927ef), [`84fffb0`](https://github.com/frontman-ai/frontman/commit/84fffb0c2badfa3dbed2b2e51c15efd4d76b5161)]:
  - @frontman-ai/frontman-client@4.0.4

## 0.1.18

### Patch Changes

- Updated dependencies [[`8368cdb`](https://github.com/frontman-ai/frontman/commit/8368cdbce2cb5181572d0143bb4d80aceea273a8), [`8368cdb`](https://github.com/frontman-ai/frontman/commit/8368cdbce2cb5181572d0143bb4d80aceea273a8), [`c36cc2b`](https://github.com/frontman-ai/frontman/commit/c36cc2bbc9536bc3898cb9ad5375a8c6006c71f8), [`8368cdb`](https://github.com/frontman-ai/frontman/commit/8368cdbce2cb5181572d0143bb4d80aceea273a8)]:
  - @frontman-ai/frontman-client@4.0.3

## 0.1.17

### Patch Changes

- Updated dependencies [[`f95c040`](https://github.com/frontman-ai/frontman/commit/f95c040e9c4e64359bd320e127de74f308f41830), [`961d660`](https://github.com/frontman-ai/frontman/commit/961d660a5c0063c3fe44f63b21e47f3f510f95be), [`5409e4f`](https://github.com/frontman-ai/frontman/commit/5409e4f97328b947fbc21c858276b16f86194e4c)]:
  - @frontman-ai/frontman-client@4.0.2

## 0.1.16

### Patch Changes

- Updated dependencies [[`d4896ac`](https://github.com/frontman-ai/frontman/commit/d4896acaf1e700e4db913103db074a099835ecb0)]:
  - @frontman-ai/frontman-client@4.0.1

## 0.1.15

### Patch Changes

- Updated dependencies [[`0bc42d9`](https://github.com/frontman-ai/frontman/commit/0bc42d9ce3a0cfd8d29e0bcbd758f7bf53a35ec8), [`373d94e`](https://github.com/frontman-ai/frontman/commit/373d94e1575d7c99368f7ac8dfa0086dfab1f7f8), [`e2cd5a0`](https://github.com/frontman-ai/frontman/commit/e2cd5a0099cdfbc8dd7f1d43bb29ff2cdf72c2f7), [`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8), [`efb4fbf`](https://github.com/frontman-ai/frontman/commit/efb4fbf27f6485c8ed0321ab8f794ed38e108df3), [`0c813c5`](https://github.com/frontman-ai/frontman/commit/0c813c5ee7fd90be929eb81a44dba7b9254761e9)]:
  - @frontman-ai/frontman-client@4.0.0

## 0.1.14

### Patch Changes

- Updated dependencies [[`65b195a`](https://github.com/frontman-ai/frontman/commit/65b195ac0ee61f89a16b99bd59c762f3e3227238), [`0b65076`](https://github.com/frontman-ai/frontman/commit/0b650768e35f354950ebb991c11985cfcd04f7e3)]:
  - @frontman-ai/frontman-client@3.0.0

## 0.1.13

### Patch Changes

- Updated dependencies [[`01667f2`](https://github.com/frontman-ai/frontman/commit/01667f23231e9d63a6ff201a82ed1581bea8f85a), [`45139a1`](https://github.com/frontman-ai/frontman/commit/45139a10873190798ada2af674f49ba4f837836f), [`4f61a67`](https://github.com/frontman-ai/frontman/commit/4f61a671b15563359126931a5db3b5d4fa54183f), [`fe076d1`](https://github.com/frontman-ai/frontman/commit/fe076d146d405ac287fc226d11a9668bff3b1f0d), [`3589e66`](https://github.com/frontman-ai/frontman/commit/3589e666cd9726fd559f6a6113d1d036436861e4), [`59604b7`](https://github.com/frontman-ai/frontman/commit/59604b75efebd4a11d93c9496b152ab26ab4ba83), [`5c25668`](https://github.com/frontman-ai/frontman/commit/5c25668ddf5f708b81ea19ab2dd7eb811c1f4b5a), [`41f323a`](https://github.com/frontman-ai/frontman/commit/41f323ae561dc0d6192aeb4bb56356efd24896d2), [`9402b2e`](https://github.com/frontman-ai/frontman/commit/9402b2e91b4133b56db5448ad818bd1e82ba4c85)]:
  - @frontman-ai/frontman-client@2.0.0

## 0.1.12

### Patch Changes

- Updated dependencies [[`1e04b55`](https://github.com/frontman-ai/frontman/commit/1e04b553677ed045415dde90b89cadd682860b2d)]:
  - @frontman-ai/frontman-client@1.0.4

## 0.1.11

### Patch Changes

- Updated dependencies [[`a363505`](https://github.com/frontman-ai/frontman/commit/a363505c228aeafd2ea6186c8004d25ccc983c48), [`b3451f2`](https://github.com/frontman-ai/frontman/commit/b3451f26d47104af6f5673e4f2fcad4f81344ef9), [`f081562`](https://github.com/frontman-ai/frontman/commit/f081562d24f17c09b2ae8bfe20467980e224ce81), [`c7848c6`](https://github.com/frontman-ai/frontman/commit/c7848c6cd137afdb8df9298789dded95675ac5e1), [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391), [`a363505`](https://github.com/frontman-ai/frontman/commit/a363505c228aeafd2ea6186c8004d25ccc983c48)]:
  - @frontman-ai/frontman-client@1.0.3

## 0.1.10

### Patch Changes

- Updated dependencies [[`8c07721`](https://github.com/frontman-ai/frontman/commit/8c077219700fbe773cadf7d55acb3165540ad7aa)]:
  - @frontman-ai/frontman-client@1.0.2

## 0.1.9

### Patch Changes

- Updated dependencies [[`2786253`](https://github.com/frontman-ai/frontman/commit/2786253055f47bc2715884acd61b71b256f31727), [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d), [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a)]:
  - @frontman-ai/frontman-client@1.0.1

## 0.1.8

### Patch Changes

- Updated dependencies [[`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d)]:
  - @frontman-ai/frontman-client@1.0.0

## 0.1.7

### Patch Changes

- Updated dependencies [[`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978), [`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978)]:
  - @frontman-ai/frontman-client@0.4.1

## 0.1.6

### Patch Changes

- Updated dependencies [[`fbbc2f6`](https://github.com/frontman-ai/frontman/commit/fbbc2f60f05f96b010fa4d593e6845fcfd8a8a2f), [`15607ba`](https://github.com/frontman-ai/frontman/commit/15607ba50fee4902372f0dcc2175d014396917d2), [`18054d0`](https://github.com/frontman-ai/frontman/commit/18054d0bec4a971f1c1a676b02cfaea9833d4b66), [`eec075b`](https://github.com/frontman-ai/frontman/commit/eec075b7d246a584dd2a8c84919f5e22b63093ab), [`cea1cff`](https://github.com/frontman-ai/frontman/commit/cea1cff2e7d84e5d66ffa42562a862f9fa447dac), [`418d99c`](https://github.com/frontman-ai/frontman/commit/418d99cd9b48e6c7948cdddea97ca13bd0f079b4), [`08d8af6`](https://github.com/frontman-ai/frontman/commit/08d8af6b4e0e1acf86480924514ffacca937de2b)]:
  - @frontman-ai/frontman-client@0.4.0

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
