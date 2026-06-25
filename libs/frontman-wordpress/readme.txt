=== Frontman - AI Website Editor for WordPress, Elementor & WooCommerce ===
Contributors: frontmanai
Tags: ai, editor, elementor, woocommerce, openai
Requires at least: 6.0
Tested up to: 6.9
Requires PHP: 7.4
Stable tag: 1.3.0
License: GPL-2.0-or-later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Edit WordPress with AI beside a live preview. Update pages, posts, Elementor layouts, WooCommerce data, menus, and settings faster.

== Description ==

**Frontman is an AI website editor for WordPress.** Open `/frontman`, describe what you want changed, and review the result beside a live preview of your site. It helps marketers, content teams, support teams, store managers, and agencies make everyday WordPress updates faster.

Frontman is not another AI chatbot or content generator. It is an editing workspace for real WordPress tasks: updating page copy, changing calls to action, editing posts, adjusting Elementor pages, refreshing WooCommerce product data, managing menus, inspecting templates, and changing safe site settings.

See it. Say it. Update it.

No code editor. No terminal. No hunting through every WordPress admin screen. Just an AI editing workflow next to the page you are working on.

== Watch Frontman in Action ==

https://www.youtube.com/watch?v=-4GD1GYwH8Y

Learn more on the [Frontman website](https://frontman.sh).

== Common Tasks ==

Use Frontman to:

* Update landing page copy, headlines, buttons, and calls to action
* Refresh blog posts, help articles, product pages, and support content
* Edit Gutenberg blocks without manually finding the right block controls
* Adjust Elementor pages with Elementor-aware editing tools
* Manage WooCommerce products, orders, customers, coupons, shipping, taxes, reports, settings, and store data when WooCommerce is active
* Update navigation menus and menu items
* Review templates, template parts, widgets, and theme settings
* Change safe site options such as title, tagline, permalinks, and homepage settings
* Inspect and update Additional CSS for the active theme

== Built for Teams That Manage WordPress Content ==

Frontman is designed for people who manage websites but do not want to work like developers.

**Marketers** can test copy, update CTAs, refresh landing pages, and make campaign changes faster.

**Content teams** can edit posts, pages, blocks, help docs, and knowledge base content from one workflow.

**Support teams** can update outdated FAQs, support pages, policy content, and product information.

**Store operators** can work with WooCommerce products, coupons, orders, reports, and store settings when WooCommerce is active.

**Agencies** can handle client edit requests faster while still reviewing changes in context.

== Live Preview Workflow ==

The important part is the feedback loop. Frontman puts the AI editor beside a live view of your site, so you can describe a change and see the result in the same workspace.

Instead of switching between admin screens, browser tabs, and page builders, you can keep the page in view while Frontman works through the edit.

== Visual Selection ==

Frontman includes select mode for visual targeting. Click a page element, describe what should change, and give the AI editor clearer context about the exact part of the page you mean.

This is useful for product cards, buttons, headlines, menu items, sections, and other page elements that are easier to point at than describe.

== Elementor Editing ==

Frontman includes Elementor-aware tools for editing Elementor pages. It can inspect Elementor page data, prepare targeted changes, and preserve versioning context so edits are easier to review and recover from.

Use it for everyday Elementor work such as changing copy, adjusting sections, updating page content, and refining existing layouts.

== WooCommerce Tools ==

When WooCommerce is active, Frontman can work with store data from the same AI editing workspace.

WooCommerce tools include products, orders, customers, coupons, shipping, taxes, reports, settings, system status, and store data.

This helps store teams make routine updates without jumping through multiple WooCommerce screens.

== WordPress Site Management ==

Frontman can work with core WordPress content and site structure:

* Posts and pages
* Gutenberg blocks
* Navigation menus and menu items
* Templates and template parts
* Widgets
* Theme settings
* Additional CSS
* Safe site options

== Safety and Permissions ==

Frontman can change real WordPress content, so access is restricted to WordPress administrators with the `manage_options` capability.

The plugin uses WordPress nonces, sanitizes inputs, and restricts option changes to a safe allowlist. Destructive edits require careful review, and you should keep backups before using any AI editing tool on an important site.

Frontman is early-access software. It works, but it has not been tested across every theme, page builder, plugin stack, and hosting setup. We recommend starting on a staging site, keeping backups, and reviewing changes carefully.

== Open Source ==

The Frontman plugin is open source under GPLv2 or later. The code is available on [GitHub](https://github.com/frontman-ai/frontman).

We are actively improving Frontman for real WordPress teams. Try it, share feedback, [open an issue](https://github.com/frontman-ai/frontman/issues), or join the conversation on GitHub.

== Why Frontman? ==

**Built for real WordPress edits**
Frontman is focused on changing your site, not only generating text.

**Live preview included**
Review the page while the AI editor works, so changes are easier to understand in context.

**Made for non-developers**
Marketers, content teams, support teams, store operators, and agencies can describe changes in plain language.

**Works with WordPress tools you already use**
Frontman supports posts, pages, Gutenberg blocks, Elementor pages, WooCommerce data, menus, templates, widgets, settings, and Additional CSS.

**Open source**
The WordPress plugin is open source and available on GitHub.

== Installation ==

1. Download the Frontman plugin release ZIP or upload the `frontman-agentic-ai-editor` folder to `/wp-content/plugins/`
2. Activate the plugin through the **Plugins** menu
3. Navigate to `/frontman` on your site (you must be logged in as an admin)
4. Start describing WordPress edits beside the live preview

== Frequently Asked Questions ==


= Do I need another server? =

No. Frontman now runs the WordPress tools, Elementor editing tools, and WooCommerce tools directly in PHP inside the plugin.

= Do I need to know code? =

No. Frontman is built for marketers, content teams, support teams, store operators, agencies, and other WordPress administrators who want to describe changes in plain language.

= Is Frontman a chatbot? =

No. Frontman uses chat as the interface, but it is an AI website editor. It can take action through WordPress tools while you review the site beside a live preview.

= Does Frontman work with Elementor? =

Yes. Frontman includes Elementor-aware tools for inspecting and editing Elementor pages.

= Does Frontman work with WooCommerce? =

Yes. When WooCommerce is active, Frontman can work with products, orders, customers, coupons, shipping, taxes, reports, settings, system status, and store data.

= Is it safe? =

Only WordPress administrators (`manage_options` capability) can access Frontman. All inputs are sanitized. Options are restricted to a safe allowlist.

= Can I use this in production? =

Technically, yes. Unlike the JavaScript framework integrations, this plugin can run on a live site. But this is experimental software. We recommend starting on a staging site, keeping backups, and reviewing changes carefully.

= Which themes work? =

Frontman's content, menu, widget, option, Elementor, and WooCommerce tools work across WordPress themes.

= What data is sent to Frontman AI? =

The Frontman UI loads from `https://app.frontman.sh`. When you submit a message, the plugin connects to `wss://api.frontman.sh` for AI agent communication. Site content and WooCommerce data may be sent when needed to process your request. See the Third-Party Services section below for details.

= Is Frontman open source? =

Yes. The Frontman plugin is open source under GPLv2 or later, and the code is available on [GitHub](https://github.com/frontman-ai/frontman).

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

1. Describe a WordPress change in chat while Frontman prepares the edit.
2. Work beside a live site preview instead of switching between admin screens.
3. Target WooCommerce product elements visually with select mode.
4. Click page elements to guide precise AI edits.

== Changelog ==

= 1.3.0 =
* Sync the Frontman plugin release with Frontman v1.3.0
* See the GitHub release notes for the full cross-product changelog

= 1.2.0 =
* Sync the Frontman plugin release with Frontman v1.2.0
* See the GitHub release notes for the full cross-product changelog

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
* Sync the Frontman plugin release with Frontman v0.17.1

= 0.17.0 =
* Sync the Frontman plugin release with Frontman v0.17.0
* See the GitHub release notes for the full cross-product changelog

= 0.16.0 =
* Sync the Frontman plugin release with Frontman v0.16.0
* See the GitHub release notes for the full cross-product changelog

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
