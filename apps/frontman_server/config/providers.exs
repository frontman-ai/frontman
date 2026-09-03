import Config

providers = [
  {:openai_codex,
   %{
     display_name: "OpenAI",
     models: [
       {"GPT-5.6 Terra", "gpt-5.6-terra"},
       {"GPT-5.6 Sol", "gpt-5.6-sol"},
       {"GPT-5.6 Luna", "gpt-5.6-luna"},
       {"GPT-5.5", "gpt-5.5"},
       {"GPT-5.4", "gpt-5.4"},
       {"GPT-5.4 Mini", "gpt-5.4-mini"},
       {"GPT-5.3 Codex Spark", "gpt-5.3-codex-spark"}
     ]
   }},
  {:anthropic,
   %{
     display_name: "Anthropic (Claude Pro/Max)",
     models: [
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
       {"GPT-5.6 Terra", "openai/gpt-5.6-terra"},
       {"GPT-5.6 Sol", "openai/gpt-5.6-sol"},
       {"GPT-5.6 Luna", "openai/gpt-5.6-luna"},
       {"GPT-5.5", "openai/gpt-5.5"},
       {"GPT-5.5 Pro", "openai/gpt-5.5-pro"},
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
       {"Kimi Latest", "~moonshotai/kimi-latest"},
       {"MiniMax M3", "minimax/minimax-m3"}
     ]
   }},
  {:fireworks_ai,
   %{
     display_name: "Fireworks AI",
     models: [
       {"Kimi K2.6 Turbo", "accounts/fireworks/routers/kimi-k2p6-turbo"}
     ]
   }},
  {:nvidia,
   %{
     display_name: "NVIDIA",
     models: [
       {"Kimi K2.6", "moonshotai/kimi-k2.6"},
       {"DeepSeek V4 Flash", "deepseek-ai/deepseek-v4-flash"},
       {"MiniMax M2.7", "minimaxai/minimax-m2.7"},
       {"Qwen3 Coder 480B", "qwen/qwen3-coder-480b-a35b-instruct"}
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
