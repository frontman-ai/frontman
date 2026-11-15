---
title: WordPress MCP Permissions and Revoking Access
description: Understand Frontman MCP authorization, WordPress Application Passwords, live-site risks, and the difference between disabling MCP and revoking access.
---

Frontman uses separate credentials for assistant access and WordPress access.
Authorizing an assistant does not connect a WordPress site automatically.

## What each credential authorizes

| Credential | Purpose |
| --- | --- |
| Frontman MCP OAuth token | Lets the external assistant request tools under your Frontman account |
| WordPress Application Password | Lets Frontman authenticate requests to your connected WordPress site |
| AI provider credential | Powers the embedded editor, not the external assistant's MCP connection |

Use the same Frontman account for the assistant and the site connection.
Frontman stores the site's Application Password encrypted. MCP clients receive site IDs and tool results, not that stored password.
The [authentication reference](/auth.md#credential-boundaries-and-ai-provider-access) describes the technical boundaries.

## WordPress permissions

The connection requires HTTPS, enabled MCP access, and an administrator account with Application Passwords available.
The plugin creates an Application Password named **Frontman MCP** after the administrator requests the connection.

This password has the WordPress user's broader REST permissions. It is not a tool-specific or read-only credential.
Frontman's MCP routes also require administrator permissions and enabled MCP access.
The available tools depend on the site's installed plugins and supported integrations.

Read access to a catalog does not establish that every write will succeed.
WordPress permissions and tool-specific checks still apply.

## Changes to a live site

Tools can change or delete content. Published pages can change before visual review.
Preview is not a universal approval gate, and only some tools require explicit confirmation.

Use a staging copy and maintain a backup before higher-risk edits.
Use [review and recovery](/docs/wordpress/recovery/) to choose a surface-specific procedure after a failed or unwanted change.
For surface-specific recovery, see [Confirmation and Rollback](/docs/integrations/wordpress/#confirmation-and-rollback).
There is no plugin-wide one-click undo.

## Disable MCP access

Open **Frontman** in WordPress, then **Settings → General**.
For a saved, enabled connection, select **Disable MCP**.
This blocks the plugin's MCP REST endpoints. It does not revoke the Application Password.

The password can still authorize other REST requests permitted for the WordPress user.
Disabling MCP is not complete credential revocation.

## Revoke the WordPress credential

1. Sign in as the WordPress user who authorized the connection.
2. Open that user's profile in WordPress.
3. Find **Application Passwords**.
4. Revoke the password named **Frontman MCP**.

Revocation stops future requests authenticated with that password.
It does not undo completed changes or establish that an already-started operation stopped.
The saved Frontman connection can remain visible after revocation, but that credential no longer authenticates site requests.

## Disconnect the assistant

Use your assistant's connected-app controls to disconnect Frontman.
The exact controls depend on the client.
Assistant disconnection does not revoke the WordPress Application Password or undo site changes.

To stop the stored WordPress credential from working, revoke it in WordPress as described above.
For connection failures after revocation, see [WordPress MCP troubleshooting](/docs/wordpress/troubleshooting/).
