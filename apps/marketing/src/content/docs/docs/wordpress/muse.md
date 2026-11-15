---
title: Meta Muse and Frontman WordPress Access
description: Review Meta Muse connector requirements, approval controls, and the missing consumer custom-MCP path before an unverified Frontman WordPress connection.
---

Meta Muse publishes a connector platform that accepts API or MCP documentation for review.
The reviewed sources do not document a consumer flow to add an arbitrary remote MCP URL.
**Frontman live OAuth compatibility with Muse remains untested in this review.**
This guide does not establish a submitted, approved, or discoverable Frontman connector.
This page concerns Meta's personal assistant at `muse.ai`.
It does not concern Muse Code or Fregio's WordPress agent.
Instructions for those products do not establish Muse connector access.

## What the connector platform supports

Muse's public guidelines cover authenticated account tools, read/write classification, and approval.
Providers submit an endpoint, authentication details, permissions, tool documentation, and a reviewer account.
Meta reviews risk, tools, and complete workflows.
Submission does not guarantee approval.

Approved connectors appear to the Muse agent and in **Settings > Connectors**.
This discovery path is separate from a private custom-server setup.
Muse's persistent cloud computer and browser are also separate from its connector platform.

## Information for your administrator or provider

1. Ask whether a Frontman connector is available for your Muse account.
2. Request its provider identity and approved tool scope.
3. If no connector exists, ask whether Muse offers an authorized private connection path.
4. Request written transport and OAuth requirements before any registration or credential exchange.

For that review, provide this Frontman contract:

| Detail | Value |
| --- | --- |
| Endpoint | `https://api.frontman.sh/mcp` |
| Transport | Streamable HTTP |
| Authentication | WorkOS OAuth with human approval |
| Account boundary | Same Frontman account for the site connection and assistant |
| Access requirement | Active subscription or eligible trial, without an extra provider key |
| Initial tools | `list_sites`, then read-only site information with `site_id` |

The [authentication reference](/auth.md) describes Frontman's discovery and authorization behavior.
The [shared setup guide](/docs/wordpress/connect-agent/) owns WordPress preparation.
If you do not administer the integration, leave credential submission to the provider.
Never send a WordPress password through Muse chat.

## First request after access exists

If your provider establishes an approved connection path, request a read before any edit:
> Use the Frontman connector, not the browser. List connected sites with IDs and hostname labels. Read site information for https://your-site.example with the matching `site_id`. Do not change anything.

Replace the example URL with your full site URL.
If labels repeat, request separate read-only site information for each candidate.

## Approval and persistent tools

Muse documents **Allow once**, **Always allow**, and **Deny** for nonsensitive tools.
Sensitive writes require approval on every use.
Those rules describe platform connectors, not an established classification of Frontman's tools.

For the first request, prefer **Allow once** over persistent approval.
Before an edit, require the exact site, object, and proposed change.
Do not assume that a read-only prompt narrows the underlying WordPress credential.

Muse advertises proactive work and a persistent cloud computer.
The reviewed connector sources do not establish background scheduling or persistent Frontman authorization behavior.
Review the connector's actual scope before unattended work.

## Diagnose the blocked stage

A missing connector is an availability or review question, not a WordPress login error.
A provider needs the endpoint, authentication method, approved tools, and exact stage that failed.
For an available connector with site errors, use [shared troubleshooting](/docs/wordpress/troubleshooting/).
For removal of site access, use [permissions and revocation](/docs/wordpress/permissions/).
No Frontman embedded preview, DOM, or screenshots pass through this external connection.

## Primary sources

Checked on November 15, 2026: Meta's [Muse product page](https://muse.ai/) and [Muse connector guidelines](https://platform.muse.ai/docs).
