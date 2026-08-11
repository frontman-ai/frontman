=== Frontman - AI Website Editor ===
Contributors: frontmanai
Tags: ai editor, website editor, elementor, woocommerce, ai
Requires at least: 6.0
Tested up to: 7.0.2
Requires PHP: 7.4
Stable tag: 3.0.0
License: GPL-2.0-or-later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Update an existing WordPress site with AI beside a live preview. Select a page element, describe the change, and review the result.

== Description ==

**Frontman is an AI editor for an existing WordPress site.** Open `/frontman`, keep the page visible, and describe the result that you want. Frontman can inspect supported WordPress structures, make the change, and refresh the preview for your review.

Use Frontman for focused site updates without hunting through page builders, theme screens, menus, widgets, and settings.

== One Task, From Request to Review ==

The screenshots show one complete task:

1. Open the page beside Frontman.
2. Select the FAQ title that needs an update.
3. Describe the new title in plain language.
4. Frontman inspects the WordPress content and applies the supported change.
5. Review the refreshed page before you continue.

For headers and footers, Frontman can inspect candidate templates, template parts, menus, widgets, and Elementor content. The structure that controls the rendered page depends on the site.

[Learn how to identify and edit a WordPress header or footer](https://frontman.sh/blog/how-to-edit-wordpress-header-footer/?utm_source=wordpress.org&utm_medium=plugin-readme&utm_campaign=frontman-wordpress&utm_content=task-proof).

== Before You Install ==

Frontman requires:

* WordPress administrator access
* A Frontman account with GitHub or Google sign-in
* A supported AI provider connected with OAuth or an API key
* A staging site and a current backup for initial use

Frontman does not include a model credential. Your provider can apply its own usage limits and charges.

== Common Tasks ==

Use Frontman to:

* Update page copy, headlines, buttons, and calls to action
* Edit posts, pages, and Gutenberg blocks
* Adjust supported Elementor content with Elementor-aware tools
* Update WooCommerce products and other supported store data
* Change navigation menus, templates, template parts, and supported widgets
* Update Additional CSS and allowlisted site settings
* Inspect a page and explain which supported WordPress structure can control it

== How Frontman Works ==

Frontman puts an AI editor beside a live view of your site. Select mode adds context from the visible element to your request.

Frontman then uses WordPress, Elementor, or WooCommerce tools that match the request. The preview refreshes after a supported change, so you can review the page in the same workspace.

Frontman works with WordPress content and structures that its current tools support. Custom themes, custom plugins, hosting controls, and unsupported page builders can require a different workflow.

== Safety, Limits, and Data ==

Only WordPress administrators with the `manage_options` capability can access Frontman. The plugin uses WordPress nonces, sanitizes inputs, and restricts option changes to an allowlist.

Frontman is early-access software. It has not been tested across every theme, page builder, plugin stack, and hosting setup.

Start on a staging site. Keep a current backup. Review each change before you use it on a production site.

When you submit a request, relevant site content can pass through Frontman AI to your configured model provider. The Third-Party Services section summarizes this data flow.

== Open Source and Support ==

The Frontman plugin is open source under GPLv2 or later. [Browse the code on GitHub](https://github.com/frontman-ai/frontman?utm_source=wordpress.org&utm_medium=plugin-readme&utm_campaign=frontman-wordpress&utm_content=open-source-section).

For product details, visit [Frontman for WordPress](https://frontman.sh/wordpress/?utm_source=wordpress.org&utm_medium=plugin-readme&utm_campaign=frontman-wordpress&utm_content=product-details). To report a problem, [open a GitHub issue](https://github.com/frontman-ai/frontman/issues?utm_source=wordpress.org&utm_medium=plugin-readme&utm_campaign=frontman-wordpress&utm_content=open-issue).

== Installation ==

1. Download the Frontman plugin release ZIP or upload the `frontman-agentic-ai-editor` folder to `/wp-content/plugins/`
2. Activate the plugin through the **Plugins** menu
3. Navigate to `/frontman` on your site (you must be logged in as an admin)
4. Sign in to Frontman at `api.frontman.sh` with GitHub or Google when prompted
5. Return to `/frontman` on your site if Frontman does not redirect you back automatically
6. Connect an AI provider with OAuth or add an API key
7. Start describing WordPress edits beside the live preview

== Frequently Asked Questions ==

= What do I need before my first task? =

You need administrator access, a Frontman account, and a supported AI provider connected with OAuth or an API key. Frontman does not include model access. You do not need another server.

= What can Frontman change? =

Current tools support posts, pages, Gutenberg blocks, menus, templates, template parts, widgets, allowlisted settings, Additional CSS, Elementor content, and WooCommerce data.

= Does Frontman work with every theme? =

No. Support depends on the structure that controls the rendered page. Custom themes, plugins, hosting controls, and unsupported builders can require another workflow.

= Can I use Frontman in production? =

Frontman can run on production, but it is early-access software. Start on staging, keep a current backup, and review each change.

= What data is sent to Frontman AI? =

The hosted service processes your prompts, relevant site or store content, tool results, and task history. It sends request context to your selected AI provider. See Third-Party Services and the Privacy Policy below.

== Third-Party Services ==

This plugin and the hosted Frontman service connect to these external services:

**Frontman Client and API**
The plugin loads its interface from `app.frontman.sh` and connects to `api.frontman.sh`. Frontman processes prompts, relevant site or store content, tool results, and stored task history to run the agent. Stored provider credentials use server-side encryption.

* Services: [Client](https://app.frontman.sh), [API](https://api.frontman.sh)
* Provider: Frontman AI
* Policies: [Terms](https://frontman.sh/terms/), [Privacy](https://frontman.sh/privacy/)

**AI Model Providers**
Frontman sends the context needed for your request to your selected AI provider. That provider processes data under its terms and privacy policy.

**WorkOS, GitHub, and Google Sign-In**
WorkOS AuthKit provides GitHub and Google sign-in. WorkOS and your selected provider process account and authentication data.

* WorkOS: [Service](https://workos.com), [Terms](https://workos.com/terms), [Privacy](https://workos.com/privacy)
* GitHub: [Service](https://github.com), [Terms](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service), [Privacy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
* Google: [Service](https://accounts.google.com), [Terms](https://policies.google.com/terms), [Privacy](https://policies.google.com/privacy)

**Analytics and Diagnostics**
Heap measures product use and onboarding. Sentry records errors and performance diagnostics. These services can process interaction, session, device, browser, identifier, and diagnostic data. Frontman uses Heap based on consent where required.

* Heap: [Service](https://heap.io), [Privacy](https://www.heap.io/privacy)
* Sentry: [Service](https://sentry.io), [Privacy](https://sentry.io/privacy/)

Loading the Frontman UI requests hosted client assets. Your site content is not sent to the Frontman API or model providers until you actively use the chat interface and submit a message.

== Screenshots ==

1. Open the FAQ page beside Frontman and identify the title that needs an update.
2. Select the title and describe the requested change in plain language.
3. Frontman inspects the WordPress content while the page remains visible.
4. Review the updated title in the refreshed page preview.

== Changelog ==

= 3.0.0 =
* Sync the Frontman plugin release with Frontman v3.0.0
* See the GitHub release notes for the full cross-product changelog

= 2.0.0 =
* Sync the Frontman plugin release with Frontman v2.0.0
* See the GitHub release notes for the full cross-product changelog

= 1.4.0 =
* Sync the Frontman plugin release with Frontman v1.4.0
* See the GitHub release notes for the full cross-product changelog

= 1.3.0 =
* Keep the WordPress plugin aligned with the Frontman v1.3.0 release train.
* Refresh WordPress.org listing metadata, including the tested WordPress version, to keep the plugin page current for new installers.
* Improve plugin-directory search copy around AI WordPress editing, live preview editing, Elementor editing, and WooCommerce store management.
* Add clearer FAQ entries for AI page editing, Elementor support, WooCommerce tools, and the live preview workflow.
* Improve screenshot captions so users can understand the AI editor, live preview, visual selection, and WooCommerce editing workflow before installing.

= 1.2.0 =
* Improve WordPress.org listing copy for non-developer WordPress teams.
* Position Frontman more clearly as an AI website editor for marketers, content teams, support teams, store operators, and agencies.
* Highlight practical editing workflows for pages, posts, Gutenberg blocks, Elementor pages, WooCommerce data, menus, templates, widgets, settings, and Additional CSS.
* Clarify the live preview workflow so users know they can review site changes beside the AI editor.
* Expand safety and third-party service details so administrators understand access controls, data flow, and recommended staging-site use before using AI editing on important sites.

= 1.1.0 =
* Update WordPress.org listing copy for non-developer WordPress teams
* Position Frontman as an AI website editor for marketers, content teams, support teams, store operators, and agencies
* Highlight live preview editing, visual selection, Elementor support, WooCommerce tools, safety controls, and third-party data handling

= 1.0.0 =
* Launch Frontman for WordPress as a self-contained AI editing plugin
* Add native tools for posts, pages, blocks, Elementor, WooCommerce, menus, templates, widgets, safe options, and Additional CSS
* Run WordPress, Elementor, and WooCommerce tools directly inside the PHP plugin
* Improve safety with admin-only access, nonces, sanitized inputs, allowlisted options, and safer CSS validation
* Strengthen WordPress source-of-truth guidance for Elementor and theme edits
* Fix WordPress admin menu icon alignment

= 0.18.2 =
* Improve Elementor mutation schemas so empty add-element, update-settings, full-page-data, and generated-child payloads are rejected before they reach Elementor

= 0.18.1 =
* Preserve existing WordPress page templates when saving or rolling back Elementor page data, and report any template side effect in Elementor tool responses

= 0.18.0 =
* Add WooCommerce tools for products, orders, customers, shipping, taxes, coupons, reports, settings, system status, and store data when WooCommerce is active

= 0.17.2 =
* Improve Elementor editing tool guidance and recovery errors for non-empty settings diffs and full-tree updates

= 0.17.1 =
* Align plugin metadata and release packaging for the next WordPress.org build

= 0.17.0 =
* Align plugin dependencies with the Frontman v0.17.0 maintenance release
* Keep WordPress package metadata current with the shared client and framework packages

= 0.16.1 =
* Fix image attachment uploads for WordPress media replacement workflows
* Strengthen Elementor rollback safety for precise widget and HTML-fragment edits

= 0.16.0 =
* Add Elementor selected-element context so Frontman can inspect and edit Elementor-backed selections more directly
* Add a WordPress media upload workflow that resolves user-provided images into Media Library attachments for posts and Elementor elements
* Preserve previous Elementor data as private rollback snapshots when updating, removing, or replacing Elementor content
* Fix WordPress page duplication so Elementor page metadata and post-backed navigation item metadata are preserved
* Run WordPress Elementor edits serially and route target metadata deterministically between settings edits and HTML-fragment edits

= 0.15.0 =
* Fix WordPress Playground relay requests so scoped tool calls and source-location POSTs keep the leading `/scope:...` path prefix
* Improve transient error handling in the shared Frontman UI with categorized errors, automatic retry, retry countdowns, and a manual retry button
* Keep WordPress editing sessions more reliable when network or relay requests fail temporarily

= 0.14.0 =
* Bump package versions for a maintenance release across the Frontman workspace

= 0.13.0 =
* Bump package versions for a maintenance release across the Frontman workspace

= 0.12.0 =
* Add production-ready WordPress support with PHP-native filesystem tools and plugin ZIP release packaging
* Add safer mutation history snapshots for WordPress editing tools
* Add richer WordPress editing tools for menus, blocks, templates, and cache workflows
* Require confirmation before destructive delete tools run
* Preserve freeform HTML during block mutations and limit widget mutations to supported safe widget types
* Remove the old standalone package and release flow from normal WordPress plugin operation

= 0.3.3 =
* Send the WordPress runtime nonce on plugin tool POST requests from the shared client
* Keep the WordPress plugin metadata aligned for the next release

= 0.3.2 =
* Remove the standalone package and remaining standalone references from the WordPress flow and release tooling
* Show a first-use caution warning reminding users to use backups and review experimental changes carefully

= 0.3.1 =
* Preserve freeform HTML while mutating blocks so block edits do not silently drop non-block content
* Restrict widget mutations to the supported safe widget types instead of generic direct option writes
* Add tests for the new menu, block, widget, template, and cache tools plus delete-confirm flows

= 0.3.0 =
* Add WordPress-native menu, block, widget, template, and cache tools that remove more admin tasks from the browser UI flow
* Require explicit confirmation for destructive WordPress delete tools before they run
* Capture pre-edit snapshots for the new mutating WordPress tools so tool history preserves the previous state

= 0.2.3 =
* Add `wp_create_menu_item` so the agent can add navigation links directly through WordPress tools
* Include pre-edit snapshots in menu item creation and update flows

= 0.2.2 =
* Include the prior asset state in mutating WordPress tool results so edit history captures what changed
* Add PHP mutation snapshot tests for posts, blocks, menus, options, and widgets

= 0.2.1 =
* Remove the extra server dependency from the WordPress plugin and release ZIP
* Run all normal file tools entirely inside the PHP plugin runtime
* Clear PHP file-tracker state on deactivate and uninstall

= 0.2.0 =
* Move the core filesystem tools into the WordPress plugin itself and stop relying on the Bun standalone for normal file operations
* Add PHP tests for the local core tool implementations

= 0.1.14 =
* For Lighthouse bootstrap, prefer using the bundled standalone binary as the Bun CLI before falling back to system Bun or installing Bun

= 0.1.13 =
* Prepare Bun and Lighthouse runtime dependencies only when the `lighthouse` tool is called, with the WordPress plugin performing the bootstrap before proxying the audit

= 0.1.12 =
* Detach bundled standalone startup more cleanly with `setsid`/stdin redirection to avoid tying the process to the originating web request

= 0.1.11 =
* Fix bundled standalone cleanup paths when Frontman classes are loaded during uninstall without bootstrap constants

= 0.1.10 =
* Install Bun on startup when needed and run `bun install` for standalone Lighthouse runtime dependencies

= 0.1.9 =
* Make `search_files` avoid Git fallback outside Git repositories and use plain filesystem search instead

= 0.1.8 =
* Improve plugin lifecycle cleanup during uninstall and deactivation

= 0.1.7 =
* Improve plugin deactivation cleanup

= 0.1.6 =
* Improve WordPress production tooling support

= 0.1.5 =
* Add plugin-side runtime logs for debugging tool execution

= 0.1.3 =
* Let `list_files` work outside Git repositories for typical WordPress hosting setups

= 0.1.2 =
* Improve file tool behavior on restrictive WordPress hosting setups

= 0.1.1 =
* Improve release packaging for the WordPress plugin

= 0.1.0 =
* Initial release
* 19 WordPress tools: posts, blocks, menus, options, templates, widgets
* File tools for theme and site editing
* Admin-only access with cookie-based authentication
* Settings page for API configuration
* Dev mode for local development
