# @frontman-ai/frontman-wordpress

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
