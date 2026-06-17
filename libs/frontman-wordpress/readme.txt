=== Frontman - Agentic AI Editor ===
Contributors: frontmanai
Tags: ai, agent, editing, elementor, woocommerce
Requires at least: 6.0
Tested up to: 6.9
Requires PHP: 7.4
Stable tag: 1.0.0
License: GPL-2.0-or-later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

AI agent that edits posts, blocks, Elementor pages, WooCommerce data, menus, templates, and site options beside a live preview.

== Description ==

Watch Frontman in action:

https://www.youtube.com/watch?v=-4GD1GYwH8Y

Learn more on the [Frontman Website](https://frontman.sh).

Frontman puts an AI agent beside a live view of your site. Open `/frontman`, describe the change you want, and the agent takes action with built-in tools while you review the result in context.

Frontman is closer to an editor than a chatbot or content generator. It is built for real editing tasks: updating content, changing blocks, adjusting Elementor pages, managing menus, inspecting templates, changing safe site options, and working with WooCommerce data when WooCommerce is active.

No code editor. No terminal. Just an AI agent workflow alongside a live page preview.

**What the agent can do:**

* Create, edit, and delete posts and pages
* Insert, update, and rearrange Gutenberg blocks
* Edit Elementor pages with Elementor-aware tools and versioning
* Manage WooCommerce products, orders, customers, coupons, shipping, taxes, reports, settings, and store data when WooCommerce is active
* Update navigation menus and menu items
* Read and change safe site options such as title, tagline, permalinks, and homepage settings
* Inspect and update Additional CSS for the active theme
* Browse block templates, template parts, widgets, and theme settings

The important part is the feedback loop. The AI agent can change the site, then you can see the result in the same workflow instead of jumping between admin screens and browser tabs.

**Who it's for:**

Developers who want faster iteration. Designers and content editors who want to make changes without opening an IDE. Store owners and site managers who would rather describe the task than dig through admin screens.

**Open source:**

The Frontman plugin is open source under GPLv2 or later. The code is available on [GitHub](https://github.com/frontman-ai/frontman).

**Early release - help us improve it:**

This is an experimental release. It works, but it hasn't been tested across every theme, page builder, and hosting setup. We're looking for users to try it and share feedback. [Open an issue](https://github.com/frontman-ai/frontman/issues) or join the conversation on GitHub.

== Installation ==

1. Download the Frontman plugin release ZIP or upload the `frontman-agentic-ai-editor` folder to `/wp-content/plugins/`
2. Activate the plugin through the **Plugins** menu
3. Navigate to `/frontman` on your site (you must be logged in as an admin)
4. Use Frontman - WordPress tools, Elementor editing, and WooCommerce tools now run directly inside the plugin

== Frequently Asked Questions ==


= Do I need another server? =

No. Frontman now runs the WordPress tools, Elementor editing tools, and WooCommerce tools directly in PHP inside the plugin.

= Is it safe? =

Only WordPress administrators (`manage_options` capability) can access Frontman. All inputs are sanitized. Options are restricted to a safe allowlist.

= Can I use this in production? =

Technically, yes. Unlike the JavaScript framework integrations, this plugin can run on a live site. But this is experimental software. We recommend starting on a staging site, keeping backups, and reviewing changes carefully.

= Which themes work? =

Frontman's content, menu, widget, option, Elementor, and WooCommerce tools work across WordPress themes.

== Third-Party Services ==

This plugin connects to external services provided by Frontman AI:

**Frontman Client (app.frontman.sh)**
The chat interface is loaded from `https://app.frontman.sh`. This serves the JavaScript and CSS that power the in-browser UI.

* Service URL: [https://app.frontman.sh](https://app.frontman.sh)
* Provider: Frontman AI
* Privacy Policy: [https://frontman.sh/terms](https://frontman.sh/terms)

**Frontman API (api.frontman.sh)**
The plugin connects via WebSocket to `wss://api.frontman.sh` for AI agent communication, sending tool results and receiving agent responses. Your site content and, when you use WooCommerce tools, store data such as products, orders, customers, coupons, reports, and settings are sent to this service when the agent processes requests.

* Service URL: [https://api.frontman.sh](https://api.frontman.sh)
* Provider: Frontman AI
* Privacy Policy: [https://frontman.sh/terms](https://frontman.sh/terms)

**AI Model Providers**
The Frontman API routes requests to third-party AI model providers (such as Anthropic and OpenAI) to generate responses. Content from your site may be included in prompts sent to these providers.

Loading the Frontman UI requests hosted client assets. Your site content is not sent to the Frontman API or model providers until you actively use the chat interface and submit a message.

== Screenshots ==

1. Frontman understands the requested content change and prepares the edit from chat.
2. Frontman runs beside a live WordPress page preview while you describe changes.
3. Frontman highlights the selected product card directly on the site.
4. Select mode lets you click page elements to target edits visually.

== Changelog ==

= 1.0.0 =
* Major release for the OpenAI provider rename and cross-package breaking changes
* See the GitHub release notes for the full cross-product changelog
* Add WordPress Additional CSS and theme mod source-inspection tools with safer CSS update validation
* Strengthen WordPress source-of-truth guidance and annotation context for Elementor/theme edits
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
* Sync the Frontman plugin release with Frontman v0.17.1

= 0.17.0 =
* Sync the Frontman plugin release with Frontman v0.17.0
* See the GitHub release notes for the full cross-product changelog

= 0.16.0 =
* Sync the Frontman plugin release with Frontman v0.16.0
* See the GitHub release notes for the full cross-product changelog

= 0.17.0 =
* Remove direct filesystem tools from the WordPress plugin while keeping WordPress API-based content editing tools

= 0.16.1 =
* Fix image attachment uploads for WordPress media replacement workflows
* Strengthen Elementor rollback safety for precise widget and HTML-fragment edits

= 0.16.0 =
* Sync the Frontman plugin release with Frontman v0.16.0
* See the GitHub release notes for the full cross-product changelog

= 0.15.0 =
* Sync the Frontman plugin release with Frontman v0.15.0
* See the GitHub release notes for the full cross-product changelog

= 0.14.0 =
* Sync the Frontman plugin release with Frontman v0.14.0
* See the GitHub release notes for the full cross-product changelog

= 0.13.0 =
* Sync the Frontman plugin release with Frontman v0.13.0
* See the GitHub release notes for the full cross-product changelog

= 0.12.0 =
* Sync the Frontman plugin release with Frontman v0.12.0
* See the GitHub release notes for the full cross-product changelog

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
