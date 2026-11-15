---
title: Connect Your AI Agent to WordPress
description: Connect an AI assistant to WordPress with Frontman MCP. Authorize your site, configure the remote connection, and check access without changing content.
---

Frontman connects an external AI assistant to your existing WordPress site through a hosted MCP server.
This guide covers site setup and a first read-only request. It does not require the embedded Frontman editor.

For the embedded-editor path instead, use [Choose Your WordPress Editing Interface](/docs/wordpress/choose-interface/).

## Requirements

- WordPress 6.0 or later and PHP 7.4 or later.
- An HTTPS site with the [Frontman WordPress plugin installed](/docs/integrations/wordpress/#installation).
- A WordPress administrator account with permission to create Application Passwords.
- A Frontman account with an active subscription or eligible subscription trial.
- An assistant that can connect to a remote MCP server through OAuth.

A trial with cancellation requested or recorded does not grant access. Free editor uses are not a subscription trial.
See [pricing](/pricing/) for current subscription terms.

Your assistant supplies the model. You do not need a separate AI provider connection or API key for hosted MCP.
The embedded editor has [separate provider requirements](/docs/api-keys/).

Site access is broad: tools can change or delete content, and published pages can change immediately.
Use staging and backups before edits. Read [WordPress MCP permissions and revocation](/docs/wordpress/permissions/) before authorization.

## 1. Connect your WordPress site

1. Sign in to WordPress as an administrator.
2. Open **Frontman** from the WordPress admin menu.
3. Sign in to the Frontman account with your subscription or eligible trial.
4. Open **Settings → General**, or select **Connect your agent** if that choice appears.
5. For a new connection, select **Enable MCP and connect**.
6. If a saved connection has MCP disabled, select **Enable MCP** instead.
7. Open the [connection setup page](https://api.frontman.sh/wordpress/connect) to check access to the site's tool catalog.

The catalog check establishes read access, not write permissions.
If a provider prompt blocks the editor, select **Connect AI provider**, then switch to **General** without adding a key.

## 2. Connect your assistant

Choose a client in the [agent compatibility reference](/docs/wordpress/agents/).
Use the [ChatGPT connection guide](/docs/wordpress/chatgpt/) or [Claude connector guide](/docs/wordpress/claude/) for their documented client flows.
Use the same Frontman account that owns your WordPress connection.

For clients with a custom remote MCP connection, the server details are:

| Setting | Value |
| --- | --- |
| MCP server URL | `https://api.frontman.sh/mcp` |
| Transport | Streamable HTTP |
| Authentication | OAuth through Frontman's WorkOS authorization flow |

Complete sign-in and approval in the browser. A WordPress password or AI provider key is not an MCP bearer token.
Client support for MCP alone does not establish compatibility with this transport and authorization flow.
Client settings, plan restrictions and administrator policies can differ.

This guide does not establish end-to-end compatibility for every assistant.
For client developers, [the authentication reference](/auth.md) describes resource discovery, OAuth registration and PKCE.

## 3. Check access without edits

Ask your assistant:

> List my connected WordPress sites. Do not change anything.

The assistant uses `list_sites`. The result must include the intended site before you request an edit.
The list contains saved connections, not a guarantee that their credentials still work.
If no sites appear, use [the connection troubleshooting guide](/docs/wordpress/troubleshooting/#no-wordpress-sites-appear).

Then ask:

> Select the site at https://your-site.example and read its site information. Do not change anything.

Replace the example URL with your site's URL.
Check that the response describes the correct installation.
The assistant must pass the returned site's ID as `site_id` for site-specific tools.

## Multiple sites and browser access

Connect each installation under the same Frontman account to make it available to that account's assistant.
Name the intended site in each request. Discovery returns IDs and hostname labels, not full URLs.
If labels repeat, ask the assistant to read each candidate's site information before it selects an installation for edits.
A site ID is not a credential or permission to access another account's site.
Multiple connected installations do not establish WordPress Multisite support.

The hosted connection sends requests from Frontman to WordPress.
You do not need to keep the embedded Frontman editor tab open for those site tools.
This does not give an external assistant the editor's browser preview, screenshots or DOM tools.

## Next steps

Choose a bounded workflow after the read-only check succeeds:

| Task | Guide |
| --- | --- |
| Create a draft or edit existing content | [WordPress posts and pages](/docs/wordpress/posts-and-pages/) |
| Change a specific block without replacing the page | [Gutenberg blocks](/docs/wordpress/gutenberg/) |
| Update one builder element | [Elementor pages](/docs/wordpress/elementor/) |
| Update a product description | [WooCommerce products](/docs/wordpress/woocommerce-products/) |
| Change a search title or description | [SEO metadata](/docs/wordpress/seo-metadata/) |
| Select the right installation | [Multiple connected sites](/docs/wordpress/multiple-sites/) |

- Use [review and recovery](/docs/wordpress/recovery/) to define the checks and recovery path before edits.
- Review [WordPress capabilities and recovery limits](/docs/integrations/wordpress/#what-the-agent-can-do).
- Read [permissions and revocation](/docs/wordpress/permissions/) before changes to a live site.
- Use [connection troubleshooting](/docs/wordpress/troubleshooting/) for account, subscription and authentication failures.

If you prefer chat beside a live site preview, use the [embedded WordPress editor](/docs/integrations/wordpress/#use-the-frontman-editor) instead.
