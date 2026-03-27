---
title: Models & Providers
description: Complete list of AI providers, authentication methods, and available models in Frontman — including defaults, tiers, and model IDs.
---

Frontman supports multiple AI providers. The available models depend on your provider and how you authenticate. See **[API Keys & Providers](/docs/api-keys/)** for setup instructions.

## Provider overview

| Provider | Auth methods | Models |
|----------|-------------|--------|
| **OpenRouter** | API key, env variable, free tier | GPT-5.x, Claude family, Gemini, Kimi, Minimax, and more |
| **Anthropic** | OAuth, API key, env variable | Claude Opus 4.6, Sonnet 4.5, Opus 4.5, Haiku 4.5, Sonnet 4, Opus 4 |
| **OpenAI (ChatGPT)** | OAuth | GPT-5.4, GPT-5.3 Codex, GPT-5.2, GPT-5.1 Codex variants |
| **Google** | API key | Gemini 3 Pro/Flash, Gemini 2.5 Pro (via OpenRouter) |
| **xAI** | API key | Grok models (via OpenRouter) |

## OpenRouter

OpenRouter gives access to the widest range of models through a single API key. It's also the provider behind Frontman's free tier.

**Default model:** Gemini 3 Flash Preview
**Auth:** API key, environment variable, or free tier
**Get a key:** [openrouter.ai/keys](https://openrouter.ai/keys)

### Full model list (own key)

| Model | ID |
|-------|----|
| GPT-5.4 Pro | `openai/gpt-5.4-pro` |
| GPT-5.4 | `openai/gpt-5.4` |
| GPT-5.3 Codex | `openai/gpt-5.3-codex` |
| GPT-5.2 | `openai/gpt-5.2` |
| GPT-5.1 | `openai/gpt-5.1` |
| GPT-5 | `openai/gpt-5` |
| GPT-5 mini | `openai/gpt-5-mini` |
| GPT-5 Chat | `openai/gpt-5-chat` |
| GPT-4.1 | `openai/gpt-4.1` |
| o3 | `openai/o3` |
| o4-mini | `openai/o4-mini` |
| Claude Opus 4.6 | `anthropic/claude-opus-4.6` |
| Claude Sonnet 4.5 | `anthropic/claude-sonnet-4.5` |
| Claude Opus 4.5 | `anthropic/claude-opus-4.5` |
| Claude Haiku 4.5 | `anthropic/claude-haiku-4.5` |
| Gemini 3 Pro Preview | `google/gemini-3-pro-preview` |
| Gemini 3 Flash Preview | `google/gemini-3-flash-preview` |
| Gemini 2.5 Pro | `google/gemini-2.5-pro` |

### Free tier models

Available without an API key. Limited to **10 requests** per user — no sign-up required.

| Model | ID |
|-------|----|
| Gemini 3 Flash | `google/gemini-3-flash-preview` |
| Claude Haiku 4.5 | `anthropic/claude-haiku-4.5` |
| Kimi K2.5 | `moonshotai/kimi-k2.5` |
| Minimax M2.5 | `minimax/minimax-m2.5` |

## Anthropic

Direct access to Claude models via API key, environment variable, or OAuth with your Claude Pro/Max subscription.

**Default model:** Claude Sonnet 4.5
**Auth:** OAuth, API key, environment variable
**Get a key:** [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)

| Model | ID |
|-------|----|
| Claude Opus 4.6 | `claude-opus-4-6` |
| Claude Sonnet 4.5 | `claude-sonnet-4-5` |
| Claude Opus 4.5 | `claude-opus-4-5` |
| Claude Haiku 4.5 | `claude-haiku-4-5` |
| Claude Sonnet 4 | `claude-sonnet-4-20250514` |
| Claude Opus 4 | `claude-opus-4-20250514` |

## OpenAI (ChatGPT)

Access GPT models by connecting your ChatGPT Pro/Plus subscription via OAuth.

**Default model:** GPT-5.4
**Auth:** OAuth only

| Model | ID |
|-------|----|
| GPT-5.4 | `gpt-5.4` |
| GPT-5.3 Codex | `gpt-5.3-codex` |
| GPT-5.2 Codex | `gpt-5.2-codex` |
| GPT-5.2 | `gpt-5.2` |
| GPT-5.1 Codex Max | `gpt-5.1-codex-max` |
| GPT-5.1 Codex Mini | `gpt-5.1-codex-mini` |

## Google

Google Gemini models are available through OpenRouter with an OpenRouter API key. You can also use a Google API key directly.

**Auth:** API key
**Get a key:** [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

Google models available through OpenRouter are listed in the [OpenRouter section](#openrouter) above.

## xAI

Grok models are available through OpenRouter with an OpenRouter API key. You can also use an xAI API key directly.

**Auth:** API key
**Get a key:** [console.x.ai](https://console.x.ai/)

## How defaults are chosen

When multiple providers are available, Frontman picks the default model from the highest-priority provider:

1. **OpenAI** (priority 10)
2. **Anthropic** (priority 20)
3. **OpenRouter** (priority 30)
4. **Google** (priority 40)
5. **xAI** (priority 50)

For example, if you have both an Anthropic API key and an OpenRouter key, Frontman defaults to Claude Sonnet 4.5 (Anthropic). You can always switch models from the dropdown in the chat header.

## Tiers

Each provider has a **full** tier (all models, available with your own key or OAuth) and some have a **free** tier (limited models, using Frontman's built-in server key):

- **Full** — Own key or OAuth → access to all models listed above
- **Free** — No key needed → limited to the [free tier models](#free-tier-models) (OpenRouter only)
