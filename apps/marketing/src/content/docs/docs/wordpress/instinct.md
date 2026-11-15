---
title: Instinct and Frontman WordPress Access
description: Identify Instinct's documented account access, privacy boundaries, and missing public custom-MCP setup before a Frontman WordPress connection attempt.
---

Instinct is the personal assistant from Spear Street Technology, Inc.
The reviewed official pages do not document a generic remote-MCP connection flow.
**Frontman live OAuth compatibility with Instinct remains untested in this review.**
The MSP server documented at `mcp.mspmcp.com` is unrelated to this assistant.

## What Instinct documents

Instinct describes an assistant that accepts text or calls and can use a phone or computer.
Its privacy policy describes connected services, Google Workspace access, and Google OAuth identity information.
Those features do not establish arbitrary OAuth authorization for a remote MCP server.

## Questions that resolve the blocker

Before any connection attempt, ask Instinct support or your administrator:

1. Does this Instinct client accept a user-supplied remote MCP URL?
2. Does it support Streamable HTTP rather than only local tools or browser work?
3. Can it discover protected resources and complete OAuth with S256 PKCE?
4. Which client identity method and exact callback URI does it use?
5. Where does a user approve, inspect, and revoke that connection?
6. Which controls prevent writes and unattended actions?

A concrete response needs a documented setup path, not a general statement that Instinct can use websites.
Do not paste a WordPress password into chat to compensate for missing connection support.

## Frontman details for the review

Provide `https://api.frontman.sh/mcp` as the endpoint.
Frontman uses Streamable HTTP and WorkOS OAuth with human approval.
The [authentication reference](/auth.md) describes metadata, dynamic registration, and credential boundaries.

The assistant must authorize the same Frontman account that owns the WordPress connection.
An active subscription or eligible trial grants hosted access.
A trial with cancellation requested or recorded does not grant access.
An extra AI provider key is not necessary.
Use [shared site preparation](/docs/wordpress/connect-agent/) for WordPress requirements.

## A bounded first request

If Instinct supplies a documented connection path, request only this initial read:

> Use Frontman MCP only. Call `list_sites` and show its IDs and hostname labels. Read site information for https://your-site.example with the matching `site_id`. Do not edit or use browser automation.

Replace the example URL with your full site URL.
If the assistant offers website access instead, ask for evidence of an actual Frontman tool call.
If no MCP tool is available, stop the connection attempt.
The returned site information must distinguish installations with the same hostname.

## Persistent access and private information

Instinct's privacy policy describes autonomous actions and information from connected accounts.
It does not specify Frontman tool approvals, token refresh, or background task controls.
Do not schedule WordPress edits until those controls and client compatibility are established.

The policy permits model improvement from some service data and describes an opt-out for future model training.
Google Workspace data has separate restrictions.
Those Google restrictions do not establish how Instinct treats WordPress tool results.
Review the current policy before allowing private drafts or customer data into the assistant.

## Diagnostics and alternatives

For missing MCP controls, return the six questions to Instinct support.
For authorization errors after a documented connection, record the client version, timestamp, failed step, and sanitized error.
For site discovery errors, use [shared troubleshooting](/docs/wordpress/troubleshooting/).
Use [permissions and revocation](/docs/wordpress/permissions/) to stop future site access.

Instinct does not receive Frontman's embedded preview, DOM, or screenshots through this contract.
For a documented custom-server path today, consult [ChatGPT](/docs/wordpress/chatgpt/) or [Claude](/docs/wordpress/claude/).
Their Frontman live OAuth compatibility also remains untested here.

## Primary sources

Checked on November 15, 2026: the [Instinct product page](https://instinct.com/) and [privacy policy](https://instinct.com/privacy-policy).
