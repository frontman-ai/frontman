---
title: Models & Providers
description: Complete list of AI providers, authentication methods, and available model IDs in Frontman.
---

Frontman supports multiple AI providers. The available models depend on your provider and how you authenticate. See **[API Keys & Providers](/docs/api-keys/)** for setup instructions.

## Provider overview

| Provider | Auth methods | Models |
|----------|-------------|--------|
| **OpenRouter** | API key | GPT-5.x, Claude family, Gemini, Kimi, Minimax, and more |
| **Anthropic** | OAuth, API key | Claude Opus 4.6, Sonnet 4.5, Opus 4.5, Haiku 4.5, Sonnet 4, Opus 4 |
| **OpenAI** | OAuth | GPT-5.5, GPT-5.4, GPT-5.3 Codex, GPT-5.2, GPT-5.1 Codex variants |
| **Google** | API key | Gemini 3 Pro/Flash, Gemini 2.5 Pro (via OpenRouter) |
| **xAI** | API key | Grok models (via OpenRouter) |

## OpenRouter

OpenRouter gives access to the widest range of models through a single API key.

**Auth:** API key
**Get a key:** [openrouter.ai/keys](https://openrouter.ai/keys)

### Model list

| Model | ID |
|-------|----|
| GPT-5.5 | `openai/gpt-5.5` |
| GPT-5.5 Pro | `openai/gpt-5.5-pro` |
| GPT-5.4 Pro | `openai/gpt-5.4-pro` |
| GPT-5.4 | `openai/gpt-5.4` |
| GPT-5.3 Codex | `openai/gpt-5.3-codex` |
| Claude Opus 4.8 | `anthropic/claude-opus-4.8` |
| Claude Opus 4.8 Fast | `anthropic/claude-opus-4.8-fast` |
| Claude Opus 4.7 | `anthropic/claude-opus-4.7` |
| Claude Opus 4.7 Fast | `anthropic/claude-opus-4.7-fast` |
| Claude Sonnet Latest | `anthropic/claude-sonnet-latest` |
| Claude Haiku Latest | `anthropic/claude-haiku-latest` |
| Gemini 3.1 Pro Preview | `google/gemini-3.1-pro-preview` |
| Gemini Flash Latest | `~google/gemini-flash-latest` |
| Kimi Latest | `~moonshotai/kimi-latest` |
| MiniMax M2.7 | `minimax/minimax-m2.7` |

## Anthropic

Direct access to Claude models via API key or OAuth with your Claude Pro/Max subscription.

**Auth:** OAuth, API key
**Get a key:** [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)

| Model | ID |
|-------|----|
| Claude Opus 4.8 | `claude-opus-4-8` |
| Claude Opus 4.7 | `claude-opus-4-7` |
| Claude Opus 4.6 | `claude-opus-4-6` |
| Claude Opus 4.5 | `claude-opus-4-5` |
| Claude Opus 4 | `claude-opus-4-20250514` |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` |
| Claude Sonnet 4 | `claude-sonnet-4-20250514` |
| Claude Haiku 4.5 | `claude-haiku-4-5` |

## OpenAI

Access GPT models by connecting your OpenAI account via OAuth.

**Auth:** OAuth only

| Model | ID |
|-------|----|
| GPT-5.5 | `gpt-5.5` |
| GPT-5.4 | `gpt-5.4` |
| GPT-5.4 Mini | `gpt-5.4-mini` |
| GPT-5.3 Codex Spark | `gpt-5.3-codex-spark` |

## Google

Google Gemini models are available through OpenRouter with an OpenRouter API key. You can also use a Google API key directly.

**Auth:** API key
**Get a key:** [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

Google models available through OpenRouter are listed in the [OpenRouter section](#openrouter) above.

## xAI

Grok models are available through OpenRouter with an OpenRouter API key. You can also use an xAI API key directly.

**Auth:** API key
**Get a key:** [console.x.ai](https://console.x.ai/)

## Initial selection

When model options load, Frontman selects the first available model in the dropdown. If you connect a new provider, Frontman switches to the first model from that provider.

You can always switch models from the dropdown in the chat header.

## Authentication

Frontman does not include a built-in server key or no-key free tier. Connect a provider with OAuth or save an API key in settings.
