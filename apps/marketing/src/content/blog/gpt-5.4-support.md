---
title: 'GPT-5.4 Support in Frontman'
pubDate: 2026-03-06T12:00:00Z
description: 'How to select GPT-5.4 in Frontman, which model IDs the integrations use, and where to verify current capabilities and pricing.'
author: 'Danni Friedland'
image: '/blog/gpt-5.4-support-cover.png'
imageAlt: 'GPT-5.4 support in Frontman'
articleSection: 'Product Announcement'
tags: ['announcement', 'models']
updatedDate: 2026-07-30T00:00:00Z
---

OpenAI released GPT-5.4 on March 5, 2026. Frontman added it to the model picker for direct OpenAI connections and added GPT-5.4 and GPT-5.4 Pro for OpenRouter connections.

This page records what Frontman supports and points to model references that can be checked as availability, limits, and prices change.

## Verified model support

Frontman's provider catalog currently contains these entries:

| Frontman provider | Picker label | Model ID sent by Frontman |
| ----------------- | ------------ | ------------------------- |
| OpenAI            | GPT-5.4      | `gpt-5.4`                 |
| OpenRouter        | GPT-5.4      | `openai/gpt-5.4`          |
| OpenRouter        | GPT-5.4 Pro  | `openai/gpt-5.4-pro`      |

You can verify those identifiers in Frontman's [provider configuration](https://github.com/frontman-ai/frontman/blob/main/apps/frontman_server/config/providers.exs). The original support change is also recorded in the [Frontman changelog](https://github.com/frontman-ai/frontman/blob/main/CHANGELOG.md).

Provider catalogs evolve. If a model does not appear in your picker, update Frontman first, then confirm that the model is available to your OpenAI or OpenRouter account.

## What OpenAI documents

OpenAI's [GPT-5.4 release announcement](https://openai.com/index/introducing-gpt-5-4/) describes the model as a general-purpose reasoning model for professional work, coding, tool use, and computer use. Its durable [GPT-5.4 model reference](https://developers.openai.com/api/docs/models/gpt-5.4) lists:

- model ID `gpt-5.4`;
- text and image input with text output;
- a 1,050,000-token context window and 128,000 maximum output tokens;
- function calling, image input, MCP, computer use, and other supported tools.

Those are provider capabilities, not a promise that every capability is exposed by Frontman. In Frontman, GPT-5.4 works through the tools Frontman makes available: browser inspection runs in the browser, file tools run through the local framework integration, and the hosted or self-hosted server orchestrates the loop. See [How the Agent Works](/docs/using/how-the-agent-works/) for that boundary.

## Pricing checked on July 30, 2026

OpenAI's official model reference listed standard API prices of **$2.50 per million input tokens**, **$0.25 per million cached input tokens**, and **$15 per million output tokens** for GPT-5.4 when this page was updated. Long-context requests and other processing tiers can use different rates.

Do not treat those numbers as permanent. Check OpenAI's [current API pricing](https://developers.openai.com/api/docs/pricing) before estimating cost. OpenRouter users should check the live [OpenRouter GPT-5.4 page](https://openrouter.ai/openai/gpt-5.4), because routing and provider availability can affect effective pricing.

## Select GPT-5.4 in Frontman

1. Open your project's `/frontman` route and sign in.
2. In Frontman settings, connect OpenAI or OpenRouter using a supported account connection or credential.
3. Open the model picker.
4. Choose **GPT-5.4**. OpenRouter users can also choose **GPT-5.4 Pro** when their account has access.
5. Start with a bounded task and review the resulting diff before keeping it.

Model selection changes which provider model drives the agent. It does not change Frontman's filesystem, browser, persistence, or review boundaries. Relevant context and tool results pass through the Frontman server to the provider you select; generated edits still need your normal testing and code review.

For installation, use the [getting started guide](/blog/getting-started/). For provider setup, see [API Keys and Providers](/docs/api-keys/).
