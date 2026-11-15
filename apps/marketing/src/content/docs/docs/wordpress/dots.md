---
title: OpenAI Dots and Frontman WordPress Access
description: Understand OpenAI dots app access, background research, and approval controls before you attempt an unverified Frontman WordPress MCP connection.
---

OpenAI dots are always-on agents in ChatGPT, not ordinary ChatGPT conversations.
OpenAI documents connected apps and shared ChatGPT app controls.
The reviewed sources do not establish arbitrary custom-MCP access from a dot.
**Frontman live OAuth compatibility with dots remains untested in this review.**
An available ChatGPT custom plugin does not prove that your dot can use it.
The dot's own browser and cloud computer do not establish Frontman MCP support.

## What OpenAI documents

Dots can continue tasks between conversations and use connected apps.
OpenAI provides app controls, Custom Rules, activity records, and scheduled tasks.
Availability depends on the account, market, plan, and workspace policy.
Access to dots is separate from permission to create a ChatGPT custom MCP connection.

On mobile, OpenAI documents **Customize > Plugins** in the dot's profile.
That screen uses shared ChatGPT settings, but available apps can differ.
This is an app-management path, not a documented instruction to add any MCP URL to dots.

## Establish availability before authorization

1. Ask your workspace administrator whether dots can use your custom Frontman plugin.
2. Request the supported app path and allowed actions for your account.
3. Ask whether those actions apply to direct requests, scheduled tasks, or proactive research.
4. If no supported path exists, use the [regular ChatGPT guide](/docs/wordpress/chatgpt/) instead.

The administrator needs these Frontman details:

- Endpoint: `https://api.frontman.sh/mcp`.
- Transport and authentication: Streamable HTTP with WorkOS OAuth.
- Human authorization under the same Frontman account that owns the WordPress connection.
- An active Frontman subscription or eligible trial, with no extra provider key.
- Read-only discovery through `list_sites`, followed by site information through the returned `site_id`.

Complete [shared site preparation](/docs/wordpress/connect-agent/) only for an authorized connection path.
Do not give a dot your WordPress password in chat.

## A safe first task

If your administrator establishes plugin availability, start with one direct request:

> Use only the Frontman plugin. Call `list_sites`, then read site information for https://your-site.example. Use its returned ID as `site_id`. Do not edit, schedule work, or use the browser.

Replace the example URL with your full site URL.
Ask for the tool names and returned site identity in the result.
If the dot offers browser work instead, stop the request.
A browser report is not evidence of a successful Frontman tool call.

## Background work and persistent context

OpenAI restricts proactive research to read-only connected-app tools.
That restriction applies to proactive research, not every explicitly requested or scheduled task.
It does not establish that Frontman tools are available during proactive research.

Before a scheduled task, define the site, permitted reads, timing, and required approval for changes.
Custom Rules do not grant app access or override OpenAI safeguards.
Review task activity instead of treating silence as success.

Disconnecting an app does not delete information that the dot already obtained.
Pausing a dot does not necessarily stop separate Work, Codex, or scheduled tasks.
Review those tasks separately before [revoking Frontman access](/docs/wordpress/permissions/).

## If the dot cannot use Frontman

1. Make sure that the dot uses the intended ChatGPT account and workspace.
2. Ask the administrator to inspect app availability and permitted actions for dots specifically.
3. If the app exists but authorization fails, record the failed step and sanitized error.
4. Use [shared troubleshooting](/docs/wordpress/troubleshooting/) only after distinguishing app availability from Frontman authorization.

Do not enable local-computer access as a workaround for missing MCP support.
Dots does not receive Frontman's embedded preview, DOM, or screenshots through this contract.
After a successful read, [multiple-site guidance](/docs/wordpress/multiple-sites/) explains safe site selection.

## Primary sources

Checked on November 15, 2026: OpenAI's [introducing dots](https://openai.com/index/introducing-dots/) and [getting started with your dot](https://help.openai.com/en/articles/20001530-getting-started-with-your-dot).
