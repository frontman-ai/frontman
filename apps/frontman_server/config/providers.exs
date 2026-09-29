import Config

providers = [
  {:openai_codex,
   %{
     display_name: "OpenAI",
     models: [
       {"GPT-6 Astra", "gpt-6-astra"},
       {"GPT-6 Sol", "gpt-6-sol"},
       {"GPT-6 Luna", "gpt-6-luna"},
       {"GPT-5.6 Terra", "gpt-5.6-terra"},
       {"GPT-5.6 Sol", "gpt-5.6-sol"},
       {"GPT-5.6 Luna", "gpt-5.6-luna"},
       {"GPT-5.5", "gpt-5.5"},
       {"GPT-5.3 Codex Spark", "gpt-5.3-codex-spark"}
     ]
   }},
  {:anthropic,
   %{
     display_name: "Anthropic (Claude Pro/Max)",
     models: [
       {"Claude Opus 5.5", "claude-opus-5-5"},
       {"Claude Sonnet 5.5", "claude-sonnet-5-5"},
       {"Claude Fable 5.1", "claude-fable-5-1"},
       {"Claude Opus 5", "claude-opus-5"},
       {"Claude Sonnet 5", "claude-sonnet-5"},
       {"Claude Fable 5", "claude-fable-5"},
       {"Claude Opus 4.8", "claude-opus-4-8"},
       {"Claude Opus 4.7", "claude-opus-4-7"},
       {"Claude Opus 4.6", "claude-opus-4-6"},
       {"Claude Opus 4.5", "claude-opus-4-5"},
       {"Claude Opus 4", "claude-opus-4-20250514"},
       {"Claude Sonnet 4.6", "claude-sonnet-4-6"},
       {"Claude Sonnet 4", "claude-sonnet-4-20250514"},
       {"Claude Haiku 4.5", "claude-haiku-4-5-20251001"}
     ]
   }},
  {:openrouter,
   %{
     display_name: "OpenRouter",
     models: [
       {"GPT-6 Astra", "openai/gpt-6-astra"},
       {"GPT-6 Sol", "openai/gpt-6-sol"},
       {"GPT-6 Luna", "openai/gpt-6-luna"},
       {"GPT-5.6 Terra", "openai/gpt-5.6-terra"},
       {"GPT-5.6 Sol", "openai/gpt-5.6-sol"},
       {"GPT-5.6 Luna", "openai/gpt-5.6-luna"},
       {"GPT-5.5", "openai/gpt-5.5"},
       {"GPT-5.5 Pro", "openai/gpt-5.5-pro"},
       {"Claude Opus 5.5", "anthropic/claude-opus-5.5"},
       {"Claude Sonnet 5.5", "anthropic/claude-sonnet-5.5"},
       {"Claude Fable 5.1", "anthropic/claude-fable-5.1"},
       {"Claude Opus 5", "anthropic/claude-opus-5"},
       {"Claude Sonnet 5", "anthropic/claude-sonnet-5"},
       {"Claude Opus 4.8", "anthropic/claude-opus-4.8"},
       {"Claude Sonnet Latest", "~anthropic/claude-sonnet-latest"},
       {"Claude Haiku Latest", "~anthropic/claude-haiku-latest"},
       {"Claude Sonnet 4.6", "anthropic/claude-sonnet-4.6"},
       {"Claude Haiku 4.5", "anthropic/claude-haiku-4.5"},
       {"Gemini 3.1 Pro Preview", "google/gemini-3.1-pro-preview"},
       {"Gemini Flash Latest", "~google/gemini-flash-latest"},
       {"Gemini Pro Latest", "~google/gemini-pro-latest"},
       {"Kimi Latest", "~moonshotai/kimi-latest"},
       {"MiniMax M3", "minimax/minimax-m3"},
       {"DeepSeek V4.1 Flash", "deepseek/deepseek-v4.1-flash"},
       {"GLM 5.3", "z-ai/glm-5.3"},
       {"GLM 5.3 Flash", "z-ai/glm-5.3-flash"},
       {"Qwen3.8 Max Prime", "qwen/qwen3.8-max-prime"},
       {"Grok 4.7", "x-ai/grok-4.7"}
     ]
   }},
  {:fireworks_ai,
   %{
     display_name: "Fireworks AI",
     models: [
       {"Kimi K3 Fast", "accounts/fireworks/routers/kimi-k3-fast"},
       {"Ember 1", "accounts/fireworks/models/ember-1"},
       {"DeepSeek V4.1 Flash", "accounts/fireworks/models/deepseek-v4p1-flash"},
       {"GLM 5.3 Fast", "accounts/fireworks/routers/glm-5p3-fast"},
       {"GLM 5.3 Flash", "accounts/fireworks/models/glm-5p3-flash"},
       {"MiniMax M3", "accounts/fireworks/models/minimax-m3"},
       {"Qwen3.8 Max", "accounts/fireworks/models/qwen3p8-max"}
     ]
   }},
  {:nvidia,
   %{
     display_name: "NVIDIA",
     models: [
       {"Kimi K3", "moonshotai/kimi-k3"},
       {"GLM 5.3", "z-ai/glm-5.3"},
       {"GLM 5.3 Flash", "z-ai/glm-5.3-flash"}
     ]
   }},
  {:google,
   %{
     display_name: "Google",
     models: []
   }},
  {:xai,
   %{
     display_name: "xAI",
     models: []
   }}
]

config :frontman_server, :providers, providers
