---
title: Choose Your WordPress Editing Interface
description: Choose the embedded Frontman editor or an external assistant through MCP, then use shared WordPress workflows with the right model, site and review setup.
---

You can use Frontman's WordPress tools from the embedded editor or a connected external assistant.
Choose the interface before you configure model access or site authorization.
The editing task does not inherently require MCP.

## Compare the interfaces

| Question | Embedded Frontman editor | External assistant through MCP |
| --- | --- | --- |
| Where do I work? | Chat beside the site preview inside WordPress | Your assistant's conversation or task interface |
| Which model runs the task? | A supported provider connected to Frontman | The external assistant's model |
| Do I need an additional provider connection? | Yes, for Frontman's agent | No separate provider key for Frontman MCP |
| How is the site selected? | The installation where you opened Frontman | An account-owned connection selected with `list_sites` and `site_id` |
| What browser context is available? | The embedded editor's supported preview and browser tools | MCP does not supply Frontman's preview, screenshots or DOM tools |
| How do I authorize access? | WordPress administrator sign-in and Frontman sign-in | Assistant OAuth plus a separately authorized WordPress connection |
| Must the editor tab stay open? | Browser-side tools depend on the active editor session | Hosted WordPress site tools do not need the embedded editor tab |

Both paths use the plugin's WordPress capabilities.
Available tools still depend on the site's plugins, runtime support and permissions.
This does not mean that every browser or backend tool in the embedded editor is available through hosted MCP.

## Use the embedded editor

Choose this interface when you want a conversation beside the running page.

1. [Install Frontman for WordPress](/docs/integrations/wordpress/#installation).
2. Open **Frontman** from the WordPress admin menu.
3. Complete [embedded-editor sign-in and provider setup](/docs/integrations/wordpress/#use-the-frontman-editor).
4. Open the intended page in the preview.
5. Request one bounded change.

The editor requires supported model access through Frontman's provider settings.
Its provider credentials are not external-client MCP credentials.
See [API Keys & Providers](/docs/api-keys/) for that setup.

## Use an external assistant through MCP

Choose this interface when you want WordPress tools inside an assistant you already use.

1. Read the [agent compatibility reference](/docs/wordpress/agents/).
2. Complete [WordPress site authorization and MCP setup](/docs/wordpress/connect-agent/).
3. Read [permissions and revocation](/docs/wordpress/permissions/) before granting access.
4. Complete the first read-only site check before edits.

An active Frontman subscription or eligible trial grants hosted MCP access.
Assistant plan restrictions and workspace policies apply separately.
Vendor-documented MCP support is not a live-tested Frontman integration.

## Use the same WordPress workflow

After either setup path, choose the task:

- [Create or edit posts and pages](/docs/wordpress/posts-and-pages/).
- [Edit a nested Gutenberg block](/docs/wordpress/gutenberg/).
- [Update one Elementor element](/docs/wordpress/elementor/).
- [Change a WooCommerce product description](/docs/wordpress/woocommerce-products/).
- [Update supported SEO metadata](/docs/wordpress/seo-metadata/).

Hosted examples include `site_id` to identify a saved connection.
The embedded editor operates on its current installation and uses its own advertised tool arguments.
Do not add a hosted-only `site_id` field to an embedded tool that does not advertise it.
For more than one hosted connection, use [multiple-site selection](/docs/wordpress/multiple-sites/).

## Review and recovery apply to both

WordPress writes can affect published content immediately.
The embedded preview is not a universal approval gate, and MCP authorization is not approval for every write.
Use staging and backups for higher-risk changes.
Define the [review and recovery procedure](/docs/wordpress/recovery/) before your first mutation.
