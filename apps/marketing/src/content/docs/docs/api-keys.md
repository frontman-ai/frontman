---
title: API Keys & Providers
description: Configure your AI model provider — use the free tier, bring your own key, or connect via OAuth.
---

Frontman needs access to a large language model (LLM) to power the coding agent. You have three options for connecting a provider.

## Free tier (default)

Frontman uses a bring-your-own-key model. Connect your own AI provider account to use the agent with Claude, ChatGPT, OpenRouter, or another supported provider.

:::note
The free tier is subject to rate limits and may use a smaller model. For production use or heavier workloads, bring your own key.
:::

## Bring your own key (BYOK)

Use your own API key from any supported provider for full control over model selection and costs.

### Supported providers

| Provider | Model examples | How to get a key |
|----------|---------------|-----------------|
| **OpenAI** | `gpt-4o`, `gpt-4o-mini` | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| **Anthropic** | `claude-sonnet-4-20250514`, `claude-3.5-haiku` | [console.anthropic.com](https://console.anthropic.com/) |
| **OpenRouter** | Any model on OpenRouter | [openrouter.ai](https://openrouter.ai) |

### Setting your key

Open the Frontman chat panel in your browser and click the **settings icon** (⚙️). Paste your API key in the provider field and select your preferred model.

Your key is stored locally in the browser and sent only to the model provider — it never touches Frontman's servers.

## OAuth (Google / GitHub)

Sign in with your Google or GitHub account to use Frontman's managed model access. This ties usage to your Frontman account and unlocks higher rate limits compared to the free tier.

## Next steps

- **[How the Agent Works](/docs/using/how-the-agent-works/)** — Understand the screenshot → read → edit loop
- **[Sending Prompts](/docs/using/sending-prompts/)** — Write effective prompts
