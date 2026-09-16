# @frontman-ai/frontman-wordpress

## 5.1.0

### Minor Changes

- [#1654](https://github.com/frontman-ai/frontman/pull/1654) [`ef80a78`](https://github.com/frontman-ai/frontman/commit/ef80a7840e7cdd8c03da62df460a18d0f067232a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add two provider-neutral WordPress SEO tools for reading and updating Yoast SEO Free 28.4 title and description overrides. Limit the route to tested versions, supported content types, permissions, and installations without detected SEO-plugin conflicts.

- [#1662](https://github.com/frontman-ai/frontman/pull/1662) [`fa9ff56`](https://github.com/frontman-ai/frontman/commit/fa9ff564936f692c03f9cfa1dec56155a11ed15f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add paged Elementor widget inspection with selected settings. Add server-side rollback diagnostics with reference IDs while keeping snapshot verification mandatory. Return the persisted timeout warning to the active agent so it knows tools can still execute, without changing existing server deadlines or question-tool pause behavior. Add UTF-8-safe pages to stored tool-result retrieval so agents can recover truncated text without repeating the full request.

- [#1658](https://github.com/frontman-ai/frontman/pull/1658) [`12b62f8`](https://github.com/frontman-ai/frontman/commit/12b62f806810920afac731134a074ed3c39f0f0d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add exact-text editing to `wp_update_custom_css` with `oldText`, `newText`, and optional `replaceAll`. Agents can change small sections without sending the complete stylesheet. Existing full-replacement calls remain supported.

  Add persisted-source reads, scope checks, best-effort conflict detection, and compact edit receipts. Reject edits to preprocessor-backed CSS.

- [#1663](https://github.com/frontman-ai/frontman/pull/1663) [`a7f7c4f`](https://github.com/frontman-ai/frontman/commit/a7f7c4fcb835a359eac94d444e91901f66a476f0) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add permission-checked native WordPress author assignment and bounded current-site account lookup for user-requested author tasks. Validate raw IDs and lookup inputs before coercion. Reject boundary-asterisk searches while preserving literal interior asterisks, percent signs, underscores, and quotes. Document account-identifier disclosure to the selected AI provider and task history.

- [#1657](https://github.com/frontman-ai/frontman/pull/1657) [`6097c5f`](https://github.com/frontman-ai/frontman/commit/6097c5f4b7ff390bb6b22976150060b4625306de) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add opt-in Sentry reports for unexpected WordPress PHP tool exceptions under Settings > Frontman. Bundle an isolated PHP SDK and remove sensitive data from reports. Keep expected tool errors out of Sentry and preserve tool responses if reporting fails.

- [#1656](https://github.com/frontman-ai/frontman/pull/1656) [`5238277`](https://github.com/frontman-ai/frontman/commit/52382772d70208c3ee3bf25424830ff91565d093) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Support optional custom slugs when creating or updating WordPress posts and pages. Use WordPress core sanitization and uniqueness rules, reject non-string slugs before writes, and return the persisted slug in post snapshots.

### Patch Changes

- [#1660](https://github.com/frontman-ai/frontman/pull/1660) [`43e458b`](https://github.com/frontman-ai/frontman/commit/43e458bdc3f15b67536aec87e4218c93ecfd5087) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Store Elementor undo snapshots as Unicode-escaped JSON so emoji can be saved on legacy WordPress metadata charsets. Verify snapshot contents before saving edits, preserve existing rollback history, and report rejected writes separately from readback mismatches.

- [#1628](https://github.com/frontman-ai/frontman/pull/1628) [`c4d3212`](https://github.com/frontman-ai/frontman/commit/c4d3212b925371b14c70fbdd1ef99011bf1f23a7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Warn WordPress users when their installed Frontman plugin is behind WordPress.org and direct them to update through WordPress administration. Show a persistent reminder inside Frontman when plugin auto-updates are disabled in WordPress settings, with a link to enable them.

- [#1661](https://github.com/frontman-ai/frontman/pull/1661) [`55430e4`](https://github.com/frontman-ai/frontman/commit/55430e4dd957889e7882fa10b8db36ff16ffa254) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Include the stored slug in WordPress post list results, consistent with single-post reads. Draft and pending slugs can be empty; publication applies WordPress core slug rules.

## 3.1.1

### Patch Changes

- [#1472](https://github.com/frontman-ai/frontman/pull/1472) [`b79c611`](https://github.com/frontman-ai/frontman/commit/b79c611e32c07db04150e05bd7de0097e8140e5e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Stop exposing the administrator email through bulk WordPress option discovery while preserving explicit option reads.

- [#1490](https://github.com/frontman-ai/frontman/pull/1490) [`0b65076`](https://github.com/frontman-ai/frontman/commit/0b650768e35f354950ebb991c11985cfcd04f7e3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Migrate browser MCP discovery, tool listing, and tool calls to MCP 2026-07-28.

## 3.0.1

### Patch Changes

- [#1402](https://github.com/frontman-ai/frontman/pull/1402) [`c30f33e`](https://github.com/frontman-ai/frontman/commit/c30f33ea32ecb3d50c4e8aef41c42c54a8274277) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make Frontman work immediately on WordPress sites using Plain permalinks.

- [#1409](https://github.com/frontman-ai/frontman/pull/1409) [`6732667`](https://github.com/frontman-ai/frontman/commit/673266773033f17eb9b6a7ad6929a753b18fdd75) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use explicit new-tab sign-in and sign-out flows in top-level and embedded Frontman clients. Ensure WordPress installations receive the updated hosted client instead of a browser-cached bundle.

## 2.0.1

### Patch Changes

- [#1398](https://github.com/frontman-ai/frontman/pull/1398) [`aec9778`](https://github.com/frontman-ai/frontman/commit/aec97788c63359fadd67c31e144bb99cd7984fd1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add theme-scoped WordPress Additional CSS revision listing, inspection, and confirmed restoration with current-state conflict detection and observed before/after fingerprints.

- [#1395](https://github.com/frontman-ai/frontman/pull/1395) [`beef1d6`](https://github.com/frontman-ai/frontman/commit/beef1d6f3b93f7941eb297e059e04ce1c80c359f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rework the WordPress.org listing around one visible task, disclose setup requirements before installation, clarify compatibility limits, and use one complete task demonstration instead of disconnected feature screenshots.

- [#1311](https://github.com/frontman-ai/frontman/pull/1311) [`3589e66`](https://github.com/frontman-ai/frontman/commit/3589e666cd9726fd559f6a6113d1d036436861e4) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove unsupported provider-key injection from framework runtime HTML, client settings, ACP metadata, and MCP tool-result metadata. Tool-result persistence now strips result metadata, while account-saved BYOK and provider OAuth remain unchanged.

  Make MCP tool-result `_meta` optional and generic, align WordPress results with that contract, and stop exposing the unused absolute source root to browser runtime configuration.

## 2.0.0

### Minor Changes

- [#1306](https://github.com/frontman-ai/frontman/pull/1306) [`84d9997`](https://github.com/frontman-ai/frontman/commit/84d9997834cdf0d77f42f744458e056b81602260) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add verified WordPress 7 support, including nested Gutenberg block paths, block-theme navigation tools, and WordPress 7.0.2 runtime coverage on PHP 7.4 and 8.4.

### Patch Changes

- [#1305](https://github.com/frontman-ai/frontman/pull/1305) [`a5e12f0`](https://github.com/frontman-ai/frontman/commit/a5e12f035a3fe485661e82014d0dacf5d4f6a61c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Explain required Frontman sign-in and AI provider setup in package guidance and installer completion output.

## 1.3.1

### Patch Changes

- [#1211](https://github.com/frontman-ai/frontman/pull/1211) [`114ec48`](https://github.com/frontman-ai/frontman/commit/114ec487cc76fd30dfdf9cfac5512bd10ce7be20) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Optimize the WordPress.org readme for plugin-directory search and conversion.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

## 1.3.0

### Patch Changes

- Keep the WordPress plugin aligned with the Frontman v1.3.0 release train.
- Refresh WordPress.org listing metadata, including the tested WordPress version, to keep the plugin page current for new installers.
- Improve plugin-directory search copy around AI WordPress editing, live preview editing, Elementor editing, and WooCommerce store management.
- Add clearer FAQ entries for AI page editing, Elementor support, WooCommerce tools, and the live preview workflow.
- Improve screenshot captions so users can understand the AI editor, live preview, visual selection, and WooCommerce editing workflow before installing.

## 1.2.0

### Patch Changes

- Improve WordPress.org listing copy for non-developer WordPress teams.
- Position Frontman more clearly as an AI website editor for marketers, content teams, support teams, store operators, and agencies.
- Highlight practical editing workflows for pages, posts, Gutenberg blocks, Elementor pages, WooCommerce data, menus, templates, widgets, settings, and Additional CSS.
- Clarify the live preview workflow so users know they can review site changes beside the AI editor.
- Expand safety and third-party service details so administrators understand access controls, data flow, and recommended staging-site use before using AI editing on important sites.

## 1.1.1

### Patch Changes

- [#1180](https://github.com/frontman-ai/frontman/pull/1180) [`6d4f43c`](https://github.com/frontman-ai/frontman/commit/6d4f43c883c3c634f2a905681daee117b3dcbcac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update the WordPress.org listing copy to position Frontman as an AI website editor for non-developer WordPress teams.
