# @frontman-ai/frontman-wordpress

## 5.7.0

### Minor Changes

- [#2125](https://github.com/frontman-ai/frontman/pull/2125) [`4ef3465`](https://github.com/frontman-ai/frontman/commit/4ef34650a00031ebe845ca5e63bb37db2fe7dc8d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add `edit_many` to `wp_update_post`. It checks several exact text edits against one post, supports a dry run, and returns a short receipt after one save.

- [#2127](https://github.com/frontman-ai/frontman/pull/2127) [`0ac95d8`](https://github.com/frontman-ai/frontman/commit/0ac95d8d69a2abbf59e87adcb739534c153bb609) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Expose registered WordPress tools automatically to connected MCP accounts. Preserve object property-count constraints in the relay.

- [`d4e4563`](https://github.com/frontman-ai/frontman/commit/d4e4563544cd6952ca014765958c3f5ed3237803) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read-only Code Snippets search and detail tools with scoped permission checks, bounded results, and stored activation and error-state reporting.

- [#2125](https://github.com/frontman-ai/frontman/pull/2125) [`4ef3465`](https://github.com/frontman-ai/frontman/commit/4ef34650a00031ebe845ca5e63bb37db2fe7dc8d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove the WooCommerce metadata create aliases. Use `wc_update_product_meta`, `wc_update_order_meta`, and `wc_update_customer_meta` to create or update metadata.

- [#2113](https://github.com/frontman-ai/frontman/pull/2113) [`166a7a6`](https://github.com/frontman-ai/frontman/commit/166a7a6c26da9f5df93ea8ffc4e1d8ccd7d6f5e4) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Connect WordPress to an authenticated Frontman account with verified, encrypted credentials.

### Patch Changes

- [#2125](https://github.com/frontman-ai/frontman/pull/2125) [`4ef3465`](https://github.com/frontman-ai/frontman/commit/4ef34650a00031ebe845ca5e63bb37db2fe7dc8d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reject generic creation and duplication of Additional CSS, block navigation, and theme templates. Route Additional CSS and block navigation updates through their dedicated tools. Block edits use post permissions, and post deletion checks permissions and reports permanent template removal accurately.

- [#2117](https://github.com/frontman-ai/frontman/pull/2117) [`f350392`](https://github.com/frontman-ai/frontman/commit/f350392148086cea25c954891bae84f3264aa397) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enable MCP during WordPress connection approval and show actionable errors.

- [#2128](https://github.com/frontman-ai/frontman/pull/2128) [`828fb32`](https://github.com/frontman-ai/frontman/commit/828fb3236b67c3b9b740a8ac3df32933770cb0c0) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Clarify MCP tool access and show the saved WordPress connection and site access settings.

- [#2132](https://github.com/frontman-ai/frontman/pull/2132) [`ce01fee`](https://github.com/frontman-ai/frontman/commit/ce01feed5981b90d1e1627a792d576f2b129e79b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enable strict PHP typing in the WordPress bootstrap, tool registry, and request infrastructure while preserving explicit input validation and stored settings compatibility.

## 5.6.0

### Minor Changes

- [#2083](https://github.com/frontman-ai/frontman/pull/2083) [`7890c50`](https://github.com/frontman-ai/frontman/commit/7890c50e0596dcecc69ec26f22b76ad91e787d4a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add Polylang language discovery, post-language inspection and assignment, and language-filtered post listing. Fix WP Super Cache purging on single-site installations using the plugin's supported API.

- [#2061](https://github.com/frontman-ai/frontman/pull/2061) [`3446375`](https://github.com/frontman-ai/frontman/commit/3446375ffa15bae8ff879b31cb632fb536919101) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add opt-in external post reads using native WordPress Application Password authentication and administrator permission checks.

- [#2063](https://github.com/frontman-ai/frontman/pull/2063) [`60075b3`](https://github.com/frontman-ai/frontman/commit/60075b3df0c5b2c99b9602c1e9b09ee4d561b0d2) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add authenticated discovery of the single remote post-read tool. Return its existing registry definition only when Application Password authentication, administrator permission, and the MCP setting allow access.

- [#2067](https://github.com/frontman-ai/frontman/pull/2067) [`4de62de`](https://github.com/frontman-ai/frontman/commit/4de62de619dae5907e154169df8ee23c56742221) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add a tool to save native post content as an authenticated WordPress preview without changing the published page or creating a duplicate page. Preserve conflicting editor autosaves and keep publication as a separate operation.

### Patch Changes

- [#2048](https://github.com/frontman-ai/frontman/pull/2048) [`f902eea`](https://github.com/frontman-ai/frontman/commit/f902eeaaa6e6e3a6c5b172b0db64930444c644e7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add native read-only SureRank SEO inspection for stored titles, descriptions, and focus keyphrases. Report read and write capabilities separately, preserve Yoast updates, and reject ambiguous ownership when both plugins are active.

- [#2059](https://github.com/frontman-ai/frontman/pull/2059) [`426b407`](https://github.com/frontman-ai/frontman/commit/426b407c6d121fa89c7c9045513d3aedafa1be0f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add a read-only Directorist listing inspector for directory assignment, public field values, taxonomies, and single-layout section order. Omit claim, plan, and payment meta. Editing stays a manual handoff.

- [#2046](https://github.com/frontman-ai/frontman/pull/2046) [`7d4b689`](https://github.com/frontman-ai/frontman/commit/7d4b689f1886488b4f663a54c3ec84d0f01b97fb) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add an opt-in disposable Astra fixture with Chromium storefront and real WordPress authentication coverage through the existing WordPress runtime.

- [#1996](https://github.com/frontman-ai/frontman/pull/1996) [`fb11d6d`](https://github.com/frontman-ai/frontman/commit/fb11d6dbf7b6aa4bbfab60d4f0432e7c295a59ac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Wrap modern Elementor widgets and containers in a row with an optional companion, preserving original subtree IDs and sibling placement with one rollback and one page-tree save. Legacy layouts are not supported.

- [#2072](https://github.com/frontman-ai/frontman/pull/2072) [`0acddb4`](https://github.com/frontman-ai/frontman/commit/0acddb45bf7ce1aa99712666b7abcf432b6d1d19) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return empty Elementor generated element settings as JSON objects so generated elements can be added or used as wrap companions.

- [#1996](https://github.com/frontman-ai/frontman/pull/1996) [`fb11d6d`](https://github.com/frontman-ai/frontman/commit/fb11d6dbf7b6aa4bbfab60d4f0432e7c295a59ac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Insert Elementor subtrees after a unique sibling and apply shallow root settings overrides while duplicating, with one rollback and one page save.

- [#2052](https://github.com/frontman-ai/frontman/pull/2052) [`25b8007`](https://github.com/frontman-ai/frontman/commit/25b8007fe4ec96648ba9bdbd8c277d3b2d1470f3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Anthropic request rejection caused by the SEO update tool's root `anyOf`. Keep the at-least-one-field runtime check and describe it in the tool instructions.

- [#2041](https://github.com/frontman-ai/frontman/pull/2041) [`e1df04d`](https://github.com/frontman-ai/frontman/commit/e1df04d687615a10772ecfa9daff93829224943d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Support native recently viewed product widget title/count updates and reversible per-widget WooCommerce cart/checkout visibility rules.

- [#2076](https://github.com/frontman-ai/frontman/pull/2076) [`e5db0f0`](https://github.com/frontman-ai/frontman/commit/e5db0f0d2a71977a833526b174c08cb306f656b7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add discovery, read, and single-setting update tools for registered theme Customizer settings, including Astra's indexed options. Use native permissions, validation, sanitization, and save hooks, with stale-state checks and persisted readback.

  Reuse the native save path for existing theme-mod updates. Tool documentation directs agents to native Astra settings before CSS overrides.

- [#2053](https://github.com/frontman-ai/frontman/pull/2053) [`bcdc001`](https://github.com/frontman-ai/frontman/commit/bcdc00118dce9b37da339ec5c3e9d2de3746d137) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add scoped WooCommerce catalog display read and confirmed write tools for the shop and category archives, using native Customizer validation and save with persisted readback.

  Register the native WooCommerce settings without replaying theme Customizer initialization on frontend requests. This prevents a fatal error with Astra.

- [#2043](https://github.com/frontman-ai/frontman/pull/2043) [`d6a05d2`](https://github.com/frontman-ai/frontman/commit/d6a05d2bc76cf47e1b8fdde4fdebdc3b0c94d291) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add checkout-isolated local development stacks for Delta, including WordPress,
  and configurable WordPress client and backend URLs for local development.

- [#2064](https://github.com/frontman-ai/frontman/pull/2064) [`fcfbc8e`](https://github.com/frontman-ai/frontman/commit/fcfbc8e8e2037490fbec7221e3deaa60118b739d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Move remote eligibility and input validation into the registered post-read definition. Discovery and execution use the same contract. No additional tools permit remote access.

- [#2106](https://github.com/frontman-ai/frontman/pull/2106) [`0a496e1`](https://github.com/frontman-ai/frontman/commit/0a496e127a59e42bf8dd8ba070c7d22d239e874e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show local prerequisites for MCP connections in WordPress settings.

- [#2079](https://github.com/frontman-ai/frontman/pull/2079) [`013b120`](https://github.com/frontman-ai/frontman/commit/013b1200260b476ca342e671896932fa28ca584e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Move SEO, media, and public-file validation coverage into the real WordPress runtime.

- [#2078](https://github.com/frontman-ai/frontman/pull/2078) [`f035733`](https://github.com/frontman-ai/frontman/commit/f03573360b828d42355d378df5afadcafac2c3c4) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Validate browser and remote tool arguments against their registered schemas before sanitization.

## Unreleased

- Add default-off MCP post reads with native WordPress Application Password authentication and administrator permission checks.

## 5.5.0

### Minor Changes

- [#2001](https://github.com/frontman-ai/frontman/pull/2001) [`677414f`](https://github.com/frontman-ai/frontman/commit/677414feb92fcbb344eb16354fe74a71dd10da7c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add exact-fragment editing to `wp_update_post` for user-authorized changes to draft, freeform HTML, and block HTML posts. Readbacks include a content SHA256 hash. Edit mode requires a fresh hash and one unique exact-text anchor, preserves surrounding bytes and omitted fields, and reuses existing save permissions and verification. Conflict detection is best-effort, not atomic.

### Patch Changes

- [#1840](https://github.com/frontman-ai/frontman/pull/1840) [`e59b88d`](https://github.com/frontman-ai/frontman/commit/e59b88dbf2498987444dde019be2c8ad483c62cc) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Prepare WordPress for gradual preview bridge rollout. Package a same-origin page-context bridge and declare `page-context-v1` support on the Frontman runtime-config element. The bridge stays inactive with existing clients, and prompt submission remains unchanged. Load it in the footer and include bundled dependency license notices.

- [#1971](https://github.com/frontman-ai/frontman/pull/1971) [`7993341`](https://github.com/frontman-ai/frontman/commit/79933410a671eaade0717a43a215d332429f66a0) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Clarify that `wp_update_option` supports only allowlisted core WordPress options, not arbitrary plugin-private options.

- [#1944](https://github.com/frontman-ai/frontman/pull/1944) [`f906abf`](https://github.com/frontman-ai/frontman/commit/f906abff840f76d25c6cd9bb86d4bedc240d7fe7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add approved creation of WebFactory 301 Redirects rules with duplicate checks and storage preservation checks across all pages.
  Normalize site-relative destinations when the site URL ends with a slash.

- [#1945](https://github.com/frontman-ai/frontman/pull/1945) [`d2b8e49`](https://github.com/frontman-ai/frontman/commit/d2b8e49820685fa477a96006b536363d4976412c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add approved deletion of WebFactory 301 Redirects rules with exact source and row checks.
  Verify preservation of every remaining rule, including rules beyond the first page.

- [#1995](https://github.com/frontman-ai/frontman/pull/1995) [`8bcc28f`](https://github.com/frontman-ai/frontman/commit/8bcc28f710ab61a2a6e814a592dd57c70e85c409) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add opt-in stored layout context to Elementor site-wide text search. Return each matched element's parent, sibling position, nearest layout ancestor, and narrow stored style overrides without changing matches or candidate pagination. Reject ambiguous element IDs only when context is requested. Stored overrides and unresolved global references are not computed styles.

- [#1995](https://github.com/frontman-ai/frontman/pull/1995) [`8bcc28f`](https://github.com/frontman-ai/frontman/commit/8bcc28f710ab61a2a6e814a592dd57c70e85c409) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Generate missing IDs recursively when adding or generating new Elementor subtrees. Preserve supplied IDs, reject malformed children and ID collisions before saving, and report the input path that needs repair.

- [#1946](https://github.com/frontman-ai/frontman/pull/1946) [`781935f`](https://github.com/frontman-ai/frontman/commit/781935fa28d2356eaf3a78121e6280d472caad05) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Verify WebFactory 301 Redirects and Redirection coexistence with a focused WordPress runtime suite.

- [#1941](https://github.com/frontman-ai/frontman/pull/1941) [`812ec30`](https://github.com/frontman-ai/frontman/commit/812ec308ee2a30cf051d4404a12ce13da8173a02) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reject duplicate WordPress tool names instead of silently replacing an existing handler.

- [#1943](https://github.com/frontman-ai/frontman/pull/1943) [`4f229cf`](https://github.com/frontman-ai/frontman/commit/4f229cf9a4ae30471b3178055684806c8945f282) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - WebFactory 301 Redirects now validates literal source paths and safe HTTP(S) destinations.
  Absolute destinations use the same path restrictions as site-relative destinations.

- [#1947](https://github.com/frontman-ai/frontman/pull/1947) [`b3f4e0f`](https://github.com/frontman-ai/frontman/commit/b3f4e0fe860b73063ce90d17785ac0510da0c3bb) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Verify WebFactory redirect HTTP behavior, plugin identity, and database failure boundaries.

- [#1942](https://github.com/frontman-ai/frontman/pull/1942) [`1247208`](https://github.com/frontman-ai/frontman/commit/12472082681c73ed23356f8ee15510df48d52e3b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Expose the pinned WebFactory 301 Redirects store separately from Redirection.

- [#1941](https://github.com/frontman-ai/frontman/pull/1941) [`812ec30`](https://github.com/frontman-ai/frontman/commit/812ec308ee2a30cf051d4404a12ce13da8173a02) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Report unexpected initialization, request-dispatch, and deferred UI and diagnostics admin callback failures when PHP diagnostics are enabled, while preserving WordPress hook contracts and error handling.

- [#1965](https://github.com/frontman-ai/frontman/pull/1965) [`1d6c378`](https://github.com/frontman-ai/frontman/commit/1d6c378e80801345a5977da5d05a7b9b7e2f7fe3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add opt-in installation paths to `wp_get_site_info` for read-only location checks. Keep paths out of default results and preserve administrator-only access. Report the configured WordPress root and its resolved path without exposing general filesystem tools.

- [#1954](https://github.com/frontman-ai/frontman/pull/1954) [`9d4b474`](https://github.com/frontman-ai/frontman/commit/9d4b474dd5e98609b38f33e5f5f0c8e14a5a27db) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Read and update one Yoast Free focus keyphrase through the existing guarded provider path, including sanitization, permissions, clearing, and stored readback.

- [#1953](https://github.com/frontman-ai/frontman/pull/1953) [`fccc78e`](https://github.com/frontman-ai/frontman/commit/fccc78eaf1cd0b5a925d9dc2966c5c0872b226f0) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use one field map for Yoast metadata validation, permissions, provider operations, and stored snapshots without changing tool behavior.

- [#1952](https://github.com/frontman-ai/frontman/pull/1952) [`fd3afc9`](https://github.com/frontman-ai/frontman/commit/fd3afc9149d82a19c33ef5d7ca5fe7143dc92b15) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Allow Yoast SEO Free title and description tools when the required runtime capabilities are available, instead of requiring an exact version match. Preserve provider writes, sanitization, conflict checks, permissions, and stored readback. Add Yoast 28.6 to the pinned integration-test matrix.

## 5.3.1

### Patch Changes

- [#1833](https://github.com/frontman-ai/frontman/pull/1833) [`25c573a`](https://github.com/frontman-ai/frontman/commit/25c573a13620ad7028b6dbf21f0f99c70f4de5ac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Load WordPress image and media helpers during uploads so image, audio, and video metadata, image thumbnails, and supplied alt text are saved. Delete the new attachment and its files if metadata generation throws.

- [#1911](https://github.com/frontman-ai/frontman/pull/1911) [`91ecc1a`](https://github.com/frontman-ai/frontman/commit/91ecc1a56ed5d55a1090a8e70d3dc018e1120ee7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Clarify that navigation listing returns saved wp_navigation posts, not navigation built directly in templates or template parts.

- [#1824](https://github.com/frontman-ai/frontman/pull/1824) [`a29d066`](https://github.com/frontman-ai/frontman/commit/a29d06602a9d896e9ab55b5c11cfd66253f88526) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Support creating and updating block and Custom HTML widgets, and preserve clickable links in text widgets. Widget removal retains settings for recovery with the existing move tool, including recovery from WordPress's inactive widgets. Reject noncanonical widget IDs before reading or mutating instances. Validate settings and permissions, preserve plugin metadata, and report failed saves with recovery instructions.

- [#1878](https://github.com/frontman-ai/frontman/pull/1878) [`a24dc40`](https://github.com/frontman-ai/frontman/commit/a24dc40b99ddc871f7219d2775ac529161725a82) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Report template theme-assignment failures and reject readback that resolves a different post or content. Errors after saving identify the saved post; readback errors ask the agent to inspect the template before retrying.

- [#1927](https://github.com/frontman-ai/frontman/pull/1927) [`e292959`](https://github.com/frontman-ai/frontman/commit/e292959a0af11beb9229c8a3944b0bbd519f5f21) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add separately opted-in local diagnostics for rejected WordPress API authentication, limited to cookie failure categories and software versions. Limit each category to one record per site every five minutes. Authentication and nonce behavior are unchanged.

- [#1928](https://github.com/frontman-ai/frontman/pull/1928) [`059145c`](https://github.com/frontman-ai/frontman/commit/059145c2c4a59dcb99792ee3e4d3b82b63744d2b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show a persistent WordPress login recovery banner when the relay reports that WordPress authentication is required. Keep saved work and Frontman authentication unchanged; let users log in and reload before asking the agent to continue.

- [#1929](https://github.com/frontman-ai/frontman/pull/1929) [`7e702cf`](https://github.com/frontman-ai/frontman/commit/7e702cfec7564cf4fbc647afdcbff92fdc7a6dbf) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve post embed HTML for authorized users. Reject denied or malformed content before saving, and report partial saves when native filters change the stored content.

- [#1929](https://github.com/frontman-ai/frontman/pull/1929) [`7e702cf`](https://github.com/frontman-ai/frontman/commit/7e702cfec7564cf4fbc647afdcbff92fdc7a6dbf) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Allow native page-template assignment when creating or updating pages. Validate availability before saving, preserve omitted assignments, support default resets, and return verified actual assignments with partial-save errors on persistence failure.

- [#1929](https://github.com/frontman-ai/frontman/pull/1929) [`7e702cf`](https://github.com/frontman-ai/frontman/commit/7e702cfec7564cf4fbc647afdcbff92fdc7a6dbf) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add verified, theme-linked block template and template-part creation. Reject collisions and generic orphan-producing creation paths, validate raw inputs, and report partial saves with raw-post recovery IDs. Require theme support for block templates, accept registered template-part areas, and verify stored markup before WordPress adds hooked blocks.

## 5.3.0

### Minor Changes

- [#1804](https://github.com/frontman-ai/frontman/pull/1804) [`8d3ae14`](https://github.com/frontman-ai/frontman/commit/8d3ae145e2e320c671b618703d2dc8882c67edda) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add guarded read and write tools for root robots.txt, llms.txt, and llms-full.txt on supported WordPress installations. Require an inspected revision and explicit approval before writes, retain one previous snapshot, and report local persistence separately from public verification. Physical robots.txt creation replaces generated rules and sitemap updates.

- [#1805](https://github.com/frontman-ai/frontman/pull/1805) [`9d206e5`](https://github.com/frontman-ai/frontman/commit/9d206e533338853ab05fa47a3afdb58ce409b482) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Read post categories and tags with term IDs, names, and slugs. Create and update posts with existing category and tag IDs, with validation before writes and explicit partial-write errors. Empty tags clear assignments; empty categories follow WordPress default-category rules.

- [#1820](https://github.com/frontman-ai/frontman/pull/1820) [`09d3dac`](https://github.com/frontman-ai/frontman/commit/09d3dac0ff64fdf5c270afcc41a47b7d88d18917) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add theme-mod updates through the registered Customizer setting's permissions, validation, sanitization, and save API. Extend Elementor page discovery with paginated text search across stored settings, including shared templates and nested repeater fields.

### Patch Changes

- [#1778](https://github.com/frontman-ai/frontman/pull/1778) [`37a46ea`](https://github.com/frontman-ai/frontman/commit/37a46ea789bb2019c99fcb7d48fad716800a6913) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Allow read-only access to the privacy policy page setting and comment registration/name-email requirements. Advertise supported option names in tool schemas while preserving existing write permissions.

- [#1806](https://github.com/frontman-ai/frontman/pull/1806) [`888b7aa`](https://github.com/frontman-ai/frontman/commit/888b7aaa94c1d051e3d19e497f933010a3e43aac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update plugin production-readiness wording while retaining backup, review, and staging guidance.

- [#1800](https://github.com/frontman-ai/frontman/pull/1800) [`0251bda`](https://github.com/frontman-ai/frontman/commit/0251bda2c9518e9368558b71e908e0a858ed76d6) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Explain unavailable SEO tools through `wp_get_site_info` and use the same compatibility reason for registration and direct calls. Match the tool schemas to the existing positive-ID and update-field requirements.

  Support Yoast SEO Free 19.9 on the tested WordPress 6.9.9 / PHP 8.2 combination through the existing adapter. Retain Yoast 28.4 coverage, edit permissions, sanitizers, and stored readbacks. Extend runtime checks to cover later rendered titles, descriptions, Open Graph tags, and WebPage schema. Preserve explicit social overrides. Mutation results confirm stored overrides, not complete rendered output or success on other pages.

## 5.2.0

### Minor Changes

- [#1687](https://github.com/frontman-ai/frontman/pull/1687) [`5670a5b`](https://github.com/frontman-ai/frontman/commit/5670a5b3a701f6e75d598c169e647cce1ff34f78) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Expose custom post type archive URLs and registration metadata in site information. Add permission-checked Redirection tools to list rules, create literal-path 301/302 redirects or 404/410 responses, and delete individual rules with confirmation. Keep CPT registration and PHP files unchanged.

### Patch Changes

- [#1726](https://github.com/frontman-ai/frontman/pull/1726) [`745fdcc`](https://github.com/frontman-ai/frontman/commit/745fdccf2748f97bd6422269d27ffdeedf675ed6) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read-only Angie snippet inspection through its native REST API, including legacy slug-based routes. Clarify that ordinary post reads exclude snippet metadata. Snippet editing and publishing remain unsupported.

- [#1676](https://github.com/frontman-ai/frontman/pull/1676) [`f95c040`](https://github.com/frontman-ai/frontman/commit/f95c040e9c4e64359bd320e127de74f308f41830) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Recover authenticated nonce rejections in the WordPress integration, preserve access errors, and consolidate request authorization without weakening permission checks.

- [#1665](https://github.com/frontman-ai/frontman/pull/1665) [`f0281a5`](https://github.com/frontman-ai/frontman/commit/f0281a5f9b602e909a9a2a6020bb45c0524fc60d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix WordPress.org publishing by excluding bundled dependency documentation and development tools. Preserve PHP runtime files, licenses, and author attribution, and validate the export before publishing. Keep older SVN release tags when publishing a new version.

- [#1666](https://github.com/frontman-ai/frontman/pull/1666) [`949d59f`](https://github.com/frontman-ai/frontman/commit/949d59f1d91cc0d6f05a6923ff98ec7ba0989a3e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Support editing existing Custom HTML widgets while preserving omitted content, plugin metadata, and sidebar placement. Apply WordPress HTML permissions to submitted content and reject invalid settings.

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
