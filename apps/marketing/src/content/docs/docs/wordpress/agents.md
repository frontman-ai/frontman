---
title: WordPress Agent Compatibility Reference
description: Compare ChatGPT, Claude, dots, Muse, and Instinct for Frontman WordPress access, with documented client features, connection limits, and evidence levels.
---

Frontman exposes WordPress tools through a hosted MCP server.
An assistant needs compatible transport, authorization, and tool controls to use those tools.

**Evidence date: November 15, 2026.**
All Frontman live OAuth compatibility remains untested in this review.

## Compatibility by evidence level

“Vendor-documented” describes the assistant's published capabilities.
“Source-reviewed” describes Frontman's implementation, not a successful connection from that assistant.
“Live-verified” requires an actual authorized connection and tool request.

| Assistant | Vendor-documented capability | Frontman source-reviewed behavior | Live-verified integration |
| --- | --- | --- | --- |
| [ChatGPT](/docs/wordpress/chatgpt/) | Custom remote MCP servers, OAuth, and actions, subject to plan and workspace controls | Streamable HTTP, WorkOS OAuth, account-scoped tools | Not tested |
| [Claude](/docs/wordpress/claude/) | Custom connectors by HTTPS URL, OAuth, and tool permissions | Same hosted contract, with dynamic OAuth client registration documented | Not tested |
| [OpenAI dots](/docs/wordpress/dots/) | Connected ChatGPT apps and shared app controls | Same server contract, but access from dots is not established | Not tested |
| [Meta Muse](/docs/wordpress/muse/) | Reviewed connector platform accepts API or MCP documentation | Same server contract, but no Frontman connector approval is established here | Not tested |
| [Instinct](/docs/wordpress/instinct/) | Personal assistant with connected services and computer use | Same server contract, but no public custom-MCP connection flow identified | Not tested |

ChatGPT and Claude publish custom-server instructions.
Dots app controls do not establish access to every custom ChatGPT server.
Muse connector submission is not a consumer instruction to add any MCP URL.
Instinct's browser access and Google integrations do not establish MCP client support.

## The common Frontman contract

Complete [Connect your AI agent to WordPress](/docs/wordpress/connect-agent/) before a client-specific connection attempt.

| Requirement | Frontman contract |
| --- | --- |
| MCP URL | `https://api.frontman.sh/mcp` |
| Transport | Streamable HTTP |
| Authentication | OAuth through WorkOS, with human sign-in and approval |
| Frontman access | Active subscription or eligible trial |
| Account | Same Frontman account for the site connection and assistant authorization |
| Provider key | No extra AI provider key for external MCP access |
| Site discovery | `list_sites` returns an `id` and hostname `label` for each saved connection |
| Site selection | Site-specific tools require the returned ID as `site_id` |

A trial with `cancel_at` or `canceled_at` does not grant access.
Free editor uses do not grant hosted MCP access.
The [authentication reference](/auth.md) describes discovery and credential boundaries.

## Establish access before edits

1. Use the named assistant's guide to identify its documented connection path or unresolved blocker.
2. Request `list_sites` without changes.
3. Ask for read-only site information for the intended connection.
4. Compare the returned installation with the full site URL.
5. If the identity or available tools remain unclear, stop.

Hostname labels can repeat for installations at different paths.

## Approval and browser limits

A prompt that forbids edits is useful, but it is not a server-enforced read-only credential.
Read [permissions and revocation](/docs/wordpress/permissions/) before changes to a live site.

External assistants do not receive the embedded Frontman browser preview, DOM tools, or screenshots.
For connection errors, use [WordPress MCP troubleshooting](/docs/wordpress/troubleshooting/).

## Primary sources

Sources checked on November 15, 2026:

- OpenAI: [custom MCP servers in ChatGPT](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt).
- Anthropic: [custom connectors by URL](https://claude.com/docs/connectors/custom/add-unlisted.md).
- OpenAI: [getting started with your dot](https://help.openai.com/en/articles/20001530-getting-started-with-your-dot).
- Meta: [Muse connector guidelines](https://platform.muse.ai/docs).
- Instinct: [product](https://instinct.com/) and [privacy policy](https://instinct.com/privacy-policy).
