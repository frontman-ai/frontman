---
title: API Keys & Providers
description: Configure AI model access in Frontman, choose a provider, bring your own API key, connect OAuth, and control model selection and usage costs.
---

Frontman needs access to a large language model (LLM) to power the coding agent. Connect a supported provider with OAuth or a saved API key.

## Provider access

Frontman does not include a built-in server key or no-key free tier. Runs require a provider credential for the selected model.

:::note
If a run fails with a missing API key error, connect OAuth or save an API key for the selected provider.
:::

## Bring your own key (BYOK)

Use your own API key from any supported provider for control over model selection and costs.

### Supported providers

| Provider | Model examples | How to get a key |
|----------|---------------|-----------------|
| **Anthropic** | Claude Opus, Sonnet, Haiku | [console.anthropic.com](https://console.anthropic.com/) |
| **OpenRouter** | GPT, Claude, Gemini, Kimi, MiniMax | [openrouter.ai](https://openrouter.ai) |
| **Fireworks AI** | Kimi models | [fireworks.ai](https://fireworks.ai/) |
| **NVIDIA** | Kimi, DeepSeek, MiniMax, Qwen | [build.nvidia.com](https://build.nvidia.com/) |

### Setting your key

Open the Frontman chat panel in your browser and click the **settings icon**. Paste your API key in the provider field and select your preferred model.

Your key is stored encrypted in Frontman's database and used by the server when running the agent.

## OAuth

Connect supported provider accounts directly. Frontman currently supports Anthropic OAuth for Claude Pro/Max and OpenAI device OAuth.

## Next steps

- **[How the Agent Works](/docs/using/how-the-agent-works/)** — Understand the screenshot → read → edit loop
- **[Sending Prompts](/docs/using/sending-prompts/)** — Write effective prompts
