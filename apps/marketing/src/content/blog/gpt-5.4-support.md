---
title: 'GPT-5.4 Support in Frontman'
pubDate: 2026-03-06T12:00:00Z
description: 'Frontman’s original GPT-5.4 announcement, the ChatGPT sign-in retirement, and where to find current models and pricing.'
author: 'Danni Friedland'
image: '/blog/gpt-5.4-support-cover.png'
imageAlt: 'GPT-5.4 support in Frontman'
articleSection: 'Product Announcement'
tags: ['announcement', 'models']
updatedDate: 2026-09-29T00:00:00Z
---

OpenAI released GPT-5.4 on March 5, 2026. Frontman added it for direct OpenAI connections and offered GPT-5.4 and GPT-5.4 Pro through OpenRouter. This page records that release, not the current model picker.

## September 2026 availability update

OpenAI retired GPT-5.4 and GPT-5.4 Mini from Codex with ChatGPT sign-in on August 31, 2026. Frontman no longer offers them through that connection. OpenAI recommends GPT-6 Sol and GPT-6 Luna where your account has access. See [OpenAI's retirement guidance](https://developers.openai.com/codex/models).

The retirement does not apply to the OpenAI API. Frontman's current OpenRouter catalog also differs from this original announcement. See [Models & Providers](/docs/reference/models/) for current options and [the changelog](https://github.com/frontman-ai/frontman/blob/main/CHANGELOG.md) for release history.

## Capabilities and pricing

OpenAI's [release announcement](https://openai.com/index/introducing-gpt-5-4/) and [model reference](https://developers.openai.com/api/docs/models/gpt-5.4) describe GPT-5.4's reasoning, coding, vision, and tool capabilities. Provider capabilities do not establish which tools Frontman exposes. See [How the Agent Works](/docs/using/how-the-agent-works/) for that boundary.

For API costs, use [OpenAI's current pricing](https://developers.openai.com/api/docs/pricing) or the [OpenRouter model page](https://openrouter.ai/openai/gpt-5.4). Prices and account availability can change independently of Frontman's catalog.

## Select a current model

1. Open your project's `/frontman` route and sign in.
2. Connect a provider in Frontman settings.
3. Choose a model available to your account from the model picker.
4. Start with a bounded task and review the resulting diff before keeping it.

For installation, use the [getting started guide](/blog/getting-started/). For provider setup, see [API Keys and Providers](/docs/api-keys/).
