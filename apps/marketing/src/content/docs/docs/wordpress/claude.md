---
title: Claude and WordPress Through Frontman
description: Prepare Frontman as a custom Claude connector, understand OAuth and tool permissions, and identify WordPress access limits before the first edit.
---

Claude documents custom remote MCP connectors through an HTTPS server URL.
Frontman's source uses Streamable HTTP and WorkOS OAuth.
**Frontman live OAuth compatibility with Claude remains untested in this review.**
A custom connector does not mean that Anthropic approved a Frontman directory listing.

This guide covers Claude's hosted connector interface.
Claude Code has a separate connection flow and OAuth callback behavior.

## Prepare the site and account

1. Complete the [shared WordPress setup](/docs/wordpress/connect-agent/).
2. Use the same Frontman account for the site connection and Claude authorization.
3. Make sure that the Frontman account has an active subscription or eligible trial.
4. Read [WordPress permissions](/docs/wordpress/permissions/).

No extra AI provider key is necessary for this MCP connection.
Claude documents URL connectors on Free, Pro, Max, Ultra, Team, and Enterprise.
The current Free plan allows one custom connector.

## Add the remote connector

For an individual account:

1. Open **Customize > Connectors**.
2. Select **Add**, then **Add custom connector**.
3. Enter a connector name and `https://api.frontman.sh/mcp`.
4. Select **Continue**.
5. Review the detected authentication settings.
6. Use OAuth sign-in, not **No sign-in** or a fixed WordPress credential.
7. Select **Add**.
8. If the connector shows **Connect**, select it.
9. Complete Frontman sign-in and approval in the browser.

For Team or Enterprise, an Owner normally adds the connector under **Organization settings > Connectors**.
Some Enterprise custom roles also allow connector management.
Members then connect individually under **Customize > Connectors**.
An organization entry alone does not authorize each member's Frontman account.

Claude offers published client identity, automatic registration, or an existing OAuth client.
Frontman's [authentication reference](/auth.md) documents dynamic client registration.
If the detected identity method fails, ask the administrator to compare it with **Register automatically**.
Do not invent a client ID or secret.

## Read the intended installation

1. Open a conversation.
2. Open **+ > Connectors**.
3. Turn on the Frontman connector for that conversation.
4. Send this request:

> Call `list_sites` through Frontman. Show the connection IDs and hostname labels. Do not change WordPress.

Then send:

> Read site information for https://your-site.example using the matching connection ID as `site_id`. Stop before any edit.

Replace the example URL with your full site URL.
If labels repeat, ask Claude to read the candidate installations separately.

## Keep approval separate from authentication

Claude documents tool approval requests and an **Always allow** choice for trusted servers.
For initial use, review each request instead of granting persistent approval.
Under **Customize > Connectors**, you can set an unnecessary tool's permission to **Blocked**.
Conversation toggles control connector availability in that conversation.

These controls do not turn Frontman's WordPress credential into a read-only credential.
Disconnecting Claude also does not revoke the WordPress Application Password.
Use [permissions and revocation](/docs/wordpress/permissions/) to stop site access.

## Diagnose discovery or authorization errors

Claude requires a `401` response to start sign-in through a protected resource challenge.
Its OAuth client uses S256 PKCE and requires reachable resource and authorization metadata.
The metadata `resource` must match `https://api.frontman.sh/mcp`, including `/mcp`.

For a pre-tool failure, send the administrator the exact server URL, selected identity method, and sanitized error.
The hosted Claude callback differs from Claude Code's loopback callback.
Do not copy a Claude Code callback into hosted connector setup.
Claude does not allow authentication changes after connector creation.
If an administrator replaces the connector, members must reconnect.

For account, subscription, or site errors after authorization, use [shared troubleshooting](/docs/wordpress/troubleshooting/).
Claude does not receive Frontman's embedded preview, DOM, or screenshots.
After a successful read, consult [Gutenberg workflows](/docs/wordpress/gutenberg/) for a bounded staging task.

## Primary sources

Checked on November 15, 2026: Anthropic's [custom connector guide](https://claude.com/docs/connectors/custom/add-unlisted.md) and [connector authentication reference](https://claude.com/docs/connectors/building/authentication.md).
