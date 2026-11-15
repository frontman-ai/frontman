---
title: Install and Use Frontman for WordPress
description: Install the Frontman WordPress plugin, connect ChatGPT or the Frontman editor, and troubleshoot supported site changes.
---

The Frontman WordPress plugin connects your site to an AI assistant such as ChatGPT or to the embedded Frontman editor. The editor includes a site preview for supported changes.

This guide owns WordPress installation and use. For the cross-platform support matrix, see [Frontman Framework Compatibility](/docs/reference/compatibility/). For the product overview, see [Frontman for WordPress](/).

Start with [Choose Your WordPress Editing Interface](/docs/wordpress/choose-interface/) to separate embedded-editor setup from external-agent MCP authorization.

> Keep backups and review changes carefully. Use staging for higher-risk changes. Changes to a live site can take effect before review.

## Requirements

- WordPress 6.0 or later
- PHP 7.4 or later
- An admin account (`manage_options` capability)
- A GitHub or Google account for Frontman sign-in
- Frontman service access (see [current pricing](/pricing/))

For ChatGPT, you also need an active Frontman subscription or eligible subscription trial. ChatGPT supplies the model for hosted MCP, so no additional AI provider connection or API key is required to connect the site or view Billing.

For the embedded Frontman editor, you need a supported AI provider connection or API key. Separate provider charges can apply. See [API Keys & Providers](/docs/api-keys/).

## Installation

### Install from the WordPress Plugin Directory

Install Frontman from the [WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/) in wp-admin. WordPress handles the normal plugin install and update flow.

1. In your WordPress admin, go to **Plugins → Add New Plugin**.
2. Search for **Frontman - AI Website Editor**, or open the [Frontman plugin page](https://wordpress.org/plugins/frontman-agentic-ai-editor/).
3. Click **Install Now**.
4. Click **Activate Plugin**.

## Connect an AI assistant

Use [Connect Your AI Agent to WordPress](/docs/wordpress/connect-agent/) for site authorization, the hosted MCP endpoint and a first read-only request.
Use the same Frontman account for the site and the assistant.

Connecting enables site-wide access, including tools that change or delete content.
Read [MCP permissions and revocation](/docs/wordpress/permissions/) before authorization.
For missing sites or authentication errors, use [MCP connection troubleshooting](/docs/wordpress/troubleshooting/).

## Use the Frontman editor

1. Sign in to WordPress as an admin and select **Frontman** from the admin menu.
2. If prompted, sign in to Frontman at `api.frontman.sh` with GitHub or Google.
3. Open **Settings → Providers**, or select **Edit in Frontman** if that choice is shown. Connect a supported AI provider using [Configure Frontman API Keys & Providers](/docs/api-keys/).
4. Describe the change in the chat beside the site preview.

Frontman sign-in is separate from WordPress sign-in. If the hosted sign-in page stays open, reopen **Frontman** from the WordPress admin menu.

The [existing Frontman demo](/#demo) shows the embedded editor and site preview, not the ChatGPT interface.

Sites with pretty permalinks can also open Frontman while browsing any page: append `/frontman` to the page URL (for example, `https://yoursite.com/about/frontman`) and the agent will preview that page. Sites using Plain permalinks use the admin menu entrypoint, which routes through `/index.php/frontman`.

## Where changes persist

WordPress writes affect the connected installation. Published content on a live site can change immediately, before you finish visual review. Preview is not a universal approval gate. Only some tools require confirmation.

Start with a staging copy and a backup. Draft publication and staging promotion still use your normal WordPress process. Recovery depends on the changed surface, as described in [Confirmation and Rollback](#confirmation-and-rollback).

## What the Agent Can Do

This inventory reflects Frontman WordPress plugin 3.1.0 source, verified August 27, 2026. WordPress uses dedicated `wp_*` tools, not the file and Lighthouse tools provided by Astro, Next.js, and Vite. For shared browser and backend tools, see [Frontman Agent Tool Capabilities](/docs/using/tool-capabilities/).

- **[Posts and pages](/docs/wordpress/posts-and-pages/) and [Gutenberg blocks](/docs/wordpress/gutenberg/):** list, read, create, duplicate, update, and delete posts or pages; list, read, insert, update, move, and delete blocks.
- **[Elementor, when active](/docs/wordpress/elementor/):** inspect page data and widgets; add, update, duplicate, move, remove, or generate elements; replace complete page data; flush generated CSS; list and restore Frontman rollback snapshots.
- **Navigation, templates, and widgets:** manage classic menus, menu items, menu locations, block-theme navigation menus, block templates, template parts, widget areas, and supported widget types.
- **Site settings:** read and update allowlisted core options such as title, tagline, front-page selection, permalink structure, and comment settings. Arbitrary option access is not available.
- **Additional CSS:** read and replace active-theme Additional CSS. Frontman can also list, inspect, and restore WordPress Custom CSS revisions for plain CSS.
- **Theme settings:** list active-theme Customizer/theme mods or read one mod. Plugin 3.1.0 does not expose a generic theme-mod write tool.
- **Media:** upload a user-attached image into Media Library with optional title, alt text, caption, description, and parent post. Maximum decoded upload size is 20 MB. Plugin does not expose general media browsing, editing, or deletion tools.
- **WooCommerce, when active:** `wc_*` tools cover products, categories, tags, attributes and terms, variations, reviews, orders, notes, refunds, customers, shipping, taxes, coupons, payment gateways, reports, settings, system status, store data, and product/order/customer metadata. Start with the bounded [product-description workflow](/docs/wordpress/woocommerce-products/).
- **Cache:** inspect supported cache plugins and request cache clearing.

For supported search titles and descriptions, use the [WordPress SEO metadata guide](/docs/wordpress/seo-metadata/).
For separate installations, use the [multiple-site selection guide](/docs/wordpress/multiple-sites/).

### Choose a practical editing guide

For an existing site, use the [header and footer guide](/blog/how-to-edit-wordpress-header-footer/) to identify which WordPress surface owns the change.
For layout problems, use the [mobile-friendly WordPress guide](/blog/how-to-make-wordpress-website-mobile-friendly/).
For measured loading problems, use the [Elementor performance guide](/blog/how-to-make-elementor-website-faster/), not a layout tutorial as evidence of faster loading.
These guides describe native controls or the embedded editor; they do not establish browser-preview access through hosted MCP.

## Confirmation and Rollback

- Frontman must ask for approval before calling plugin tools whose schema requires `confirm=true`. Examples include WordPress delete tools, Elementor restoration, and Additional CSS writes.
- WooCommerce endpoint tools using `PUT` or `DELETE`, and metadata writes, require `confirm=true`.
- WooCommerce `POST` create tools do not require that field. This includes product, order, and refund creation. Product creation can publish immediately; refund creation can request a payment-gateway refund.
- Post and page deletion moves content to trash by default; `force=true` permanently deletes it. Other delete tools do not promise trash or automatic restoration.
- Many mutation results include before/after state for review, but those snapshots are not a general undo system.
- Elementor content mutation tools save private rollback snapshots and return rollback IDs. `wp_elementor_list_rollbacks` finds them; `wp_elementor_restore_rollback` restores one after separate confirmation.
- No plugin-wide one-click rollback exists for Gutenberg, menus, templates, widgets, options, media, or WooCommerce. Use revisions or trash where applicable, and maintain site backups.

An assistant can ask for approval through its own controls. That is separate from the plugin enforcing a `confirm=true` field.

For a step-by-step result review and restoration decision, use [Review and Recover WordPress AI Changes](/docs/wordpress/recovery/).

Before production use, establish backup ownership, restore verification, recurring checks, and escalation rules with the [WordPress maintenance checklist](/blog/wordpress-maintenance-checklist/).

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
- Loading `/frontman` requests UI assets from Frontman's hosted client. Connected assistants can access site content through the MCP connection.

## External Services

The plugin connects to two Frontman-hosted services:

- **app.frontman.sh** — Serves the chat UI (JavaScript and CSS).
- **api.frontman.sh** — Handles AI agent communication via WebSocket. Site content is sent here when you submit a message.

The embedded editor uses your connected AI provider through the Frontman API. ChatGPT supplies the model when you use ChatGPT with hosted MCP. See the [Privacy Policy](/privacy/) for details.

## Troubleshooting

**The `/frontman` URL shows a 404.**
Flush your WordPress permalinks: go to **Settings → Permalinks** and click **Save Changes** without changing anything.

**I see a login screen instead of the Frontman UI.**
A WordPress login screen means you must log in as an administrator first. A Frontman login screen at `api.frontman.sh` is also expected on first use; sign in there with GitHub or Google, then return to `/frontman` on your site.

**Changes aren't showing on the live site.**
Use the `wp_clear_cache` tool in the chat, or flush your caching plugin manually (WP Rocket, W3 Total Cache, etc.).

**Something went wrong and I want to undo a change.**
Use Elementor's Frontman rollback tools only for Elementor changes. For posts and pages, check WordPress revisions or trash when applicable. Other mutations have no plugin-managed rollback; use your site backup or manually restore the recorded before state.
