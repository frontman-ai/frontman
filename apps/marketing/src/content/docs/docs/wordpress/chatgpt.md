---
title: ChatGPT and WordPress Through Frontman
description: Prepare a custom Frontman MCP connection in ChatGPT, understand workspace and OAuth requirements, and request a read-only WordPress site check.
---

ChatGPT documents custom remote MCP connections and write actions through server tools.
This guide applies those instructions to Frontman's source-reviewed contract.
**Frontman live OAuth compatibility with ChatGPT remains untested in this review.**
These instructions do not establish an OpenAI-approved directory listing.

## Before the connection

1. Complete the [shared WordPress setup](/docs/wordpress/connect-agent/).
2. Make sure that your Frontman account has an active subscription or eligible trial.
3. Make sure that assistant authorization uses the Frontman account that owns the site connection.
4. Read [permissions and revocation](/docs/wordpress/permissions/).

No additional AI provider key is necessary for this external connection.
OpenAI documents full custom MCP support on ChatGPT web for Business and Enterprise/Edu.
Business admins and owners can create and publish custom connections.
Enterprise/Edu can grant creation access through role-based controls.
Only admins and owners can publish connections for their workspace.

OpenAI separately documents Pro custom-server access with read/fetch permissions.
That access does not establish WordPress write access.
Mobile does not support custom-server setup.

## Add a custom server in ChatGPT

The current OpenAI guide uses **Plugins**, not a separate Developer Mode switch.

1. Open the intended ChatGPT workspace on the web.
2. Open **Plugins**.
3. Select **+**, then **Add custom MCP server**.
4. Enter a descriptive name, such as `Frontman WordPress`.
5. Under **Connection**, enter `https://api.frontman.sh/mcp`.
6. Configure OAuth for the connection.
7. Review the server risk warning.
8. Select the acknowledgment only after that review.
9. Select **Create as a plugin**.
10. Complete the Frontman sign-in and approval request in the browser.
11. Review the discovered tools and metadata before use.

Frontman uses Streamable HTTP and WorkOS OAuth.
Do not enter a WordPress password, browser cookie, or provider key as an MCP token.
If OAuth requires manual client details, ask the connection administrator to review [Frontman authentication](/auth.md).

## Make the first request read-only

1. Install the resulting plugin through ChatGPT's documented flow.
2. Start a new conversation.
3. Type `@` and select the Frontman plugin.
4. Send this request:

> Use Frontman to call `list_sites`. Show each site's ID and hostname label. Do not change anything.

Then send:

> Read site information for the connection that matches https://your-site.example. Use its returned ID as `site_id`. Do not edit anything.

Replace the example URL with your full site URL.
If hostname labels repeat, request site information for each candidate before selection.
ChatGPT app selection applies to the message, not every later message.
Mention the plugin again for a request that needs a new tool call.

## Approvals and persistent connections

ChatGPT asks for action approval according to app permissions and action context.
An OAuth approval is not approval for every future content change.
OpenAI documents read/fetch-only custom apps in deep research.
A research result does not establish write access in an ordinary conversation.
ChatGPT Workspace Agents also use separate per-agent controls.

## Diagnose a ChatGPT-specific blocker

- Missing creation controls: ask the workspace admin about the plan and **Create plugins with MCPs** permission.
- OAuth redirect error: give the administrator the exact redirect URI from the server's management page.
- Repeated sign-in: ask the administrator to inspect token refresh and advertised `offline_access` support.
- Missing or changed tools: ask an admin to review and refresh ChatGPT's stored tool snapshot.

There is no universal callback URL to copy from another account or tutorial.
For site discovery and subscription errors, use [shared troubleshooting](/docs/wordpress/troubleshooting/).

## Limits and next tasks

ChatGPT does not receive Frontman's embedded browser preview, DOM, or screenshots.
After a successful read, choose a bounded [posts and pages](/docs/wordpress/posts-and-pages/) task on staging.

## Primary sources

Checked on November 15, 2026: OpenAI's [custom MCP connection guide](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt) and [OAuth reference](https://developers.openai.com/plugins/build/auth.md).
