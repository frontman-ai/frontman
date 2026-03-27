=== Frontman - Agentic AI Editor ===
Contributors: frontmanai
Tags: ai, editing, content, gutenberg, blocks
Requires at least: 6.0
Tested up to: 6.9
Requires PHP: 7.4
Stable tag: 0.14.0
License: GPL-2.0-or-later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

AI agent for WordPress that edits posts, blocks, menus, templates, and site options from a conversational UI.

== Description ==

Agentic AI puts an AI agent inside your WordPress site. Navigate to `/frontman`, describe what you want to change, and the agent handles it — posts, pages, blocks, menus, theme files, site settings, and more.

No code editor. No terminal. Just a chat interface alongside a live view of your site.

**What the agent can do:**

* Create, edit, and delete posts and pages
* Insert, update, and rearrange Gutenberg blocks
* Edit theme files — templates, `style.css`, `theme.json`, `functions.php`
* Update navigation menus and menu items
* Read and change site options (title, tagline, permalinks, etc.)
* Browse block templates and template parts
* Search and modify files across your WordPress installation

**Who it's for:**

Developers who want faster iteration. Designers and content editors who want to make changes without opening an IDE. Anyone managing a WordPress site who'd rather describe what they want than dig through admin screens.

**Open source:**

The Frontman WordPress plugin is open source under GPLv2 or later. The code is available on [GitHub](https://github.com/frontman-ai/frontman).

**Early release — help us improve it:**

This is an experimental release. It works, but it hasn't been tested across every theme, page builder, and hosting setup. We're looking for users to try it and share feedback. [Open an issue](https://github.com/frontman-ai/frontman/issues) or join the conversation on GitHub.

== Installation ==

1. Download the Frontman plugin release ZIP or upload the `frontman` folder to `/wp-content/plugins/`
2. Activate the plugin through the **Plugins** menu
3. Navigate to `/frontman` on your site (you must be logged in as an admin)
4. Use Frontman - file tools now run directly inside the WordPress plugin

== Frequently Asked Questions ==


= Do I need another server? =

No. Frontman now runs the core file tools directly in PHP inside the WordPress plugin.

= Is it safe? =

Only WordPress administrators (`manage_options` capability) can access Frontman. All inputs are sanitized. Options are restricted to a safe allowlist.

= Can I use this in production? =

Technically, yes — unlike the JavaScript framework integrations, the WordPress plugin can run on a live site. But this is experimental software. We recommend starting on a staging site, keeping backups, and reviewing changes carefully.

= Which themes work? =

Frontman works with any WordPress theme. Block themes (Full Site Editing) and classic PHP themes are both supported. The agent adapts based on what it finds in your theme directory.

== Third-Party Services ==

This plugin connects to external services provided by Frontman AI:

**Frontman Client (app.frontman.sh)**
The chat interface is loaded from `https://app.frontman.sh`. This serves the JavaScript and CSS that power the in-browser UI.

* Service URL: [https://app.frontman.sh](https://app.frontman.sh)
* Provider: Frontman AI
* Privacy Policy: [https://frontman.sh/terms](https://frontman.sh/terms)

**Frontman API (api.frontman.sh)**
The plugin connects via WebSocket to `https://api.frontman.sh` for AI agent communication — sending tool results and receiving agent responses. Your site content is sent to this service when the agent processes requests.

* Service URL: [https://api.frontman.sh](https://api.frontman.sh)
* Provider: Frontman AI
* Privacy Policy: [https://frontman.sh/terms](https://frontman.sh/terms)

**AI Model Providers**
The Frontman API routes requests to third-party AI model providers (such as Anthropic and OpenAI) to generate responses. Content from your site may be included in prompts sent to these providers.

No data is sent to these services until you actively use the Frontman chat interface and submit a message.

== Screenshots ==

1. The Frontman chat interface alongside your WordPress site

== Changelog ==

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
