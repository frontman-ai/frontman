---
title: Install and Use Frontman for WordPress (Beta)
description: Install the Frontman WordPress plugin, connect model access, verify the editor, and troubleshoot supported site changes.
---

The Frontman WordPress plugin adds an AI agent directly to your WordPress site. Open **Frontman** from the WordPress admin menu, describe what you want to change, and the agent handles the supported workflow inside the site preview — no code editor or terminal required for those supported changes.

This guide owns WordPress installation and use. For the cross-platform support matrix, see [Frontman Framework Compatibility](/docs/reference/compatibility/). For the product overview, see [Frontman for WordPress](/wordpress/).

> **Beta:** This is experimental software. Start on a staging site, keep backups, and review changes before deploying to production.

## Requirements

- WordPress 6.0 or later
- PHP 7.4 or later
- An admin account (`manage_options` capability)
- A GitHub or Google account for Frontman sign-in
- An AI provider connection or API key

## Installation

### Install from the WordPress Plugin Directory

Install Frontman from the [WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/) in wp-admin. WordPress handles the normal plugin install and update flow.

1. In your WordPress admin, go to **Plugins → Add New Plugin**.
2. Search for **Frontman Agentic AI Editor**, or open the [Frontman plugin page](https://wordpress.org/plugins/frontman-agentic-ai-editor/).
3. Click **Install Now**.
4. Click **Activate Plugin**.

## Using Frontman

1. Make sure you're logged in to WordPress as an admin.
2. Select **Frontman** in the WordPress admin menu. The plugin chooses the correct URL for your permalink configuration.
3. If prompted, sign in to Frontman at `api.frontman.sh` with GitHub or Google. This is separate from your WordPress admin login.
4. Once signed in, return through the **Frontman** admin menu. Frontman redirects back automatically when the site URL is accepted.
5. Connect a supported AI provider with OAuth or add an API key by following [Configure Frontman API Keys & Providers](/docs/api-keys/).
6. Describe what you want to change in the chat interface beside the live preview.

Frontman attempts to return you to the same site URL after hosted sign-in. If the hosted page remains open instead, reopen **Frontman** from the WordPress admin menu after signing in. Frontman does not include a built-in model credential; see [API Keys & Providers](/docs/api-keys/).

Sites with pretty permalinks can also open Frontman while browsing any page: append `/frontman` to the page URL (for example, `https://yoursite.com/about/frontman`) and the agent will preview that page. Sites using Plain permalinks use the admin menu entrypoint, which routes through `/index.php/frontman`.

## What the Agent Can Do

This inventory reflects Frontman WordPress plugin 2.0.0 source, verified July 30, 2026. WordPress uses dedicated `wp_*` tools, not the file and Lighthouse tools provided by Astro, Next.js, and Vite. For shared browser and backend tools, see [Frontman Agent Tool Capabilities](/docs/using/tool-capabilities/).

- **Posts, pages, and Gutenberg:** list, read, create, duplicate, update, and delete posts or pages; list, read, insert, update, move, and delete blocks.
- **Elementor, when active:** inspect page data and widgets; add, update, duplicate, move, remove, or generate elements; replace complete page data; flush generated CSS; list and restore Frontman rollback snapshots.
- **Navigation, templates, and widgets:** manage classic menus, menu items, menu locations, block-theme navigation menus, block templates, template parts, widget areas, and supported widget types.
- **Site settings:** read and update allowlisted core options such as title, tagline, front-page selection, permalink structure, and comment settings. Arbitrary option access is not available.
- **Additional CSS:** read and replace active-theme Additional CSS. Frontman can also list, inspect, and restore WordPress Custom CSS revisions for plain CSS.
- **Theme settings:** list active-theme Customizer/theme mods or read one mod. Plugin 2.0.0 does not expose a generic theme-mod write tool.
- **Media:** upload a user-attached image into Media Library with optional title, alt text, caption, description, and parent post. Maximum decoded upload size is 20 MB. Plugin does not expose general media browsing, editing, or deletion tools.
- **WooCommerce, when active:** `wc_*` tools cover products, categories, tags, attributes and terms, variations, reviews, orders, notes, refunds, customers, shipping, taxes, coupons, payment gateways, reports, settings, system status, store data, and product/order/customer metadata.
- **Cache:** inspect supported cache plugins and request cache clearing.

## Confirmation and Rollback

- Frontman must ask for approval before calling plugin tools whose schema requires `confirm=true`. This includes WordPress delete tools, Elementor restoration, Additional CSS writes, and WooCommerce mutations.
- Post and page deletion moves content to trash by default; `force=true` permanently deletes it. Other delete tools do not promise trash or automatic restoration.
- Many mutation results include before/after state for review, but those snapshots are not a general undo system.
- Elementor content mutation tools save private rollback snapshots and return rollback IDs. `wp_elementor_list_rollbacks` finds them; `wp_elementor_restore_rollback` restores one after separate confirmation.
- No plugin-wide one-click rollback exists for Gutenberg, menus, templates, widgets, options, media, or WooCommerce. Use revisions or trash where applicable, and maintain site backups.

### Restore an Additional CSS revision

Frontman uses this sequence for Additional CSS recovery:

1. Read current CSS with `wp_get_custom_css`.
2. List revision metadata with `wp_list_custom_css_revisions`.
3. Inspect one revision with `wp_get_custom_css_revision`.
4. Ask for approval to restore that revision.
5. Restore it with `wp_restore_custom_css_revision` and `confirm=true`.
6. Read current CSS again and compare the observed fingerprint.

The restore tool requires the active stylesheet, current parent post ID, selected revision ID, and current SHA-256 fingerprint. These values prevent known stale writes. The fingerprint check is not an atomic lock. Another writer can change CSS after the check.

Restoration supports plain CSS only. Frontman rejects restoration when WordPress stores preprocessor source in `post_content_filtered`. WordPress revisions do not contain this source by default.

WordPress settings control revision creation and retention. A restore can create a revision, but Frontman does not promise this result. WordPress save filters can also transform restored CSS. Frontman returns the content metadata that it observes after the write.

Do not retry a restore after a lost response. Read current CSS, compare it with the known prior and target fingerprints, inspect content if necessary, and ask the user what to do.

This recovery flow has runtime coverage on WordPress 6.0.9 with PHP 7.4, WordPress 7.0.2 with PHP 7.4, and WordPress 7.0.2 with PHP 8.4. This matrix does not claim coverage for every intermediate version.

## Security

- Only users with the `manage_options` capability can access Frontman.
- Tool call requests (POST) are validated with WordPress nonces.
- Site options are restricted to a safe allowlist — arbitrary option writes are not permitted.
- Loading `/frontman` requests UI assets from Frontman's hosted client. Your site content is not sent to Frontman's API until you actively submit a message in the chat.

## External Services

The plugin connects to two Frontman-hosted services:

- **app.frontman.sh** — Serves the chat UI (JavaScript and CSS).
- **api.frontman.sh** — Handles AI agent communication via WebSocket. Site content is sent here when you submit a message.

AI responses are generated by third-party providers (Anthropic, OpenAI, etc.) via the Frontman API. See the [Privacy Policy](/privacy/) for details.

## Troubleshooting

**The `/frontman` URL shows a 404.**
Flush your WordPress permalinks: go to **Settings → Permalinks** and click **Save Changes** without changing anything.

**I see a login screen instead of the Frontman UI.**
A WordPress login screen means you must log in as an administrator first. A Frontman login screen at `api.frontman.sh` is also expected on first use; sign in there with GitHub or Google, then return to `/frontman` on your site.

**Changes aren't showing on the live site.**
Use the `wp_clear_cache` tool in the chat, or flush your caching plugin manually (WP Rocket, W3 Total Cache, etc.).

**Something went wrong and I want to undo a change.**
Use Elementor's Frontman rollback tools only for Elementor changes. For posts and pages, check WordPress revisions or trash when applicable. Other mutations have no plugin-managed rollback; use your site backup or manually restore the recorded before state.
