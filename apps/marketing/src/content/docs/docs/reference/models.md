---
title: Models & Providers
description: Compare Frontman's supported AI providers, current model IDs, authentication methods, account restrictions, and model selection behavior.
---

Frontman offers a curated catalog of models for text, coding, and tool use. A catalog entry does not guarantee access through your account. Provider plans, workspace rules, and rollouts can restrict access.

This reference was reviewed on September 29, 2026. The [provider configuration](https://github.com/frontman-ai/frontman/blob/main/apps/frontman_server/config/providers.exs) defines the picker options and validates execution requests. See [API Keys & Providers](/docs/api-keys/) for connection instructions.

## OpenAI

**Connection:** ChatGPT OAuth through Codex, not an OpenAI API key.

| Model | ID |
|-------|----|
| GPT-6 Astra | `gpt-6-astra` |
| GPT-6 Sol | `gpt-6-sol` |
| GPT-6 Luna | `gpt-6-luna` |
| GPT-5.6 Terra | `gpt-5.6-terra` |
| GPT-5.6 Sol | `gpt-5.6-sol` |
| GPT-5.6 Luna | `gpt-5.6-luna` |
| GPT-5.5 | `gpt-5.5` |
| GPT-5.3 Codex Spark | `gpt-5.3-codex-spark` |

OpenAI retired GPT-5.4 and GPT-5.4 Mini from Codex with ChatGPT sign-in on August 31, 2026. Their API availability is separate. GPT-5.5 retires from ChatGPT sign-in on October 14, 2026. Sol and Luna access depends on your plan, client, workspace, and rollout. See [OpenAI's Codex model guidance](https://developers.openai.com/codex/models).

## Anthropic

**Connection:** Anthropic API key or OAuth with an eligible Claude subscription. Account access still applies to each model.

| Model | ID |
|-------|----|
| Claude Opus 5.5 | `claude-opus-5-5` |
| Claude Sonnet 5.5 | `claude-sonnet-5-5` |
| Claude Fable 5.1 | `claude-fable-5-1` |
| Claude Opus 5 | `claude-opus-5` |
| Claude Sonnet 5 | `claude-sonnet-5` |
| Claude Fable 5 | `claude-fable-5` |
| Claude Opus 4.8 | `claude-opus-4-8` |
| Claude Opus 4.7 | `claude-opus-4-7` |
| Claude Opus 4.6 | `claude-opus-4-6` |
| Claude Opus 4.5 | `claude-opus-4-5` |
| Claude Opus 4 | `claude-opus-4-20250514` |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` |
| Claude Sonnet 4 | `claude-sonnet-4-20250514` |
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` |

See [Anthropic's model reference](https://platform.claude.com/docs/en/about-claude/models/overview) and [Claude Code model configuration](https://code.claude.com/docs/en/model-config) for capabilities and subscription restrictions.

## OpenRouter

**Connection:** OpenRouter API key. IDs belong to OpenRouter, not to the upstream provider's direct connection.

| Model | ID |
|-------|----|
| GPT-6 Astra | `openai/gpt-6-astra` |
| GPT-6 Sol | `openai/gpt-6-sol` |
| GPT-6 Luna | `openai/gpt-6-luna` |
| GPT-5.6 Terra | `openai/gpt-5.6-terra` |
| GPT-5.6 Sol | `openai/gpt-5.6-sol` |
| GPT-5.6 Luna | `openai/gpt-5.6-luna` |
| GPT-5.5 | `openai/gpt-5.5` |
| GPT-5.5 Pro | `openai/gpt-5.5-pro` |
| Claude Opus 5.5 | `anthropic/claude-opus-5.5` |
| Claude Sonnet 5.5 | `anthropic/claude-sonnet-5.5` |
| Claude Fable 5.1 | `anthropic/claude-fable-5.1` |
| Claude Opus 5 | `anthropic/claude-opus-5` |
| Claude Sonnet 5 | `anthropic/claude-sonnet-5` |
| Claude Opus 4.8 | `anthropic/claude-opus-4.8` |
| Claude Sonnet Latest | `~anthropic/claude-sonnet-latest` |
| Claude Haiku Latest | `~anthropic/claude-haiku-latest` |
| Claude Sonnet 4.6 | `anthropic/claude-sonnet-4.6` |
| Claude Haiku 4.5 | `anthropic/claude-haiku-4.5` |
| Gemini 3.1 Pro Preview | `google/gemini-3.1-pro-preview` |
| Gemini Flash Latest | `~google/gemini-flash-latest` |
| Gemini Pro Latest | `~google/gemini-pro-latest` |
| Kimi Latest | `~moonshotai/kimi-latest` |
| MiniMax M3 | `minimax/minimax-m3` |
| DeepSeek V4.1 Flash | `deepseek/deepseek-v4.1-flash` |
| GLM 5.3 | `z-ai/glm-5.3` |
| GLM 5.3 Flash | `z-ai/glm-5.3-flash` |
| Qwen3.8 Max Prime | `qwen/qwen3.8-max-prime` |
| Grok 4.7 | `x-ai/grok-4.7` |

Keep the leading `~` in latest-model aliases. OpenRouter can change the model behind an alias. The [live OpenRouter catalog](https://openrouter.ai/api/v1/models) lists current IDs and supported parameters.

## Fireworks AI

**Connection:** Fireworks API key. Router IDs and model IDs are distinct API identifiers.

| Model | ID |
|-------|----|
| Kimi K3 Fast | `accounts/fireworks/routers/kimi-k3-fast` |
| Ember 1 | `accounts/fireworks/models/ember-1` |
| DeepSeek V4.1 Flash | `accounts/fireworks/models/deepseek-v4p1-flash` |
| GLM 5.3 Fast | `accounts/fireworks/routers/glm-5p3-fast` |
| GLM 5.3 Flash | `accounts/fireworks/models/glm-5p3-flash` |
| MiniMax M3 | `accounts/fireworks/models/minimax-m3` |
| Qwen3.8 Max | `accounts/fireworks/models/qwen3p8-max` |

## NVIDIA

**Connection:** NVIDIA API key for the NVIDIA-hosted endpoint.

| Model | ID |
|-------|----|
| Kimi K3 | `moonshotai/kimi-k3` |
| GLM 5.3 | `z-ai/glm-5.3` |
| GLM 5.3 Flash | `z-ai/glm-5.3-flash` |

## Selection and availability

Frontman preserves a saved selection while it remains in the catalog. Otherwise, it selects the first available option. A newly connected provider selects its first model. Use the dropdown in the chat header to change models.

Google and xAI have no direct picker entries. Use their listed models through OpenRouter. An upstream model in LLMDB is not automatically a Frontman option. ReqLLM must also support its request format, authentication, and tool streaming.

If a provider rejects a model, select an available replacement and send a new message. Retrying a failed turn keeps its original model. Frontman does not silently move your request to another provider.
