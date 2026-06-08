import Config

# Provider config. Client model options and custom LLMDB model metadata are
# derived from this ordered list.
#
# Fields:
#   :env_key_name        – metadata key the client sends for project-level keys (nil = n/a)
#   :display_name        – human-readable label for the UI
#   :max_image_dimension – hard pixel-per-side limit (nil = provider auto-resizes)
# Model tuple shape: {display_name, model_id, llm_db_metadata | :packaged}
providers = [
  {:openai_codex,
   %{
     env_key_name: nil,
     display_name: "OpenAI",
     max_image_dimension: nil,
     llm_db_provider: [],
     default_model: "gpt-5.5",
     models: [
       {"GPT-5.5", "gpt-5.5", :packaged},
       {"GPT-5.4", "gpt-5.4", :packaged},
       {"GPT-5.4 Mini", "gpt-5.4-mini", :packaged},
       {"GPT-5.3 Codex Spark", "gpt-5.3-codex-spark", :packaged}
     ]
   }},
  {:anthropic,
   %{
     env_key_name: "anthropicKeyValue",
     display_name: "Anthropic (Claude Pro/Max)",
     # Anthropic hard-rejects images > 8000px per side; 7680 leaves margin.
     max_image_dimension: 7680,
     llm_db_provider: [],
     default_model: "claude-sonnet-4-6",
     models: [
       {"Claude Opus 4.8", "claude-opus-4-8", :packaged},
       {"Claude Opus 4.7", "claude-opus-4-7", :packaged},
       {"Claude Opus 4.6", "claude-opus-4-6", :packaged},
       {"Claude Opus 4.5", "claude-opus-4-5", :packaged},
       {"Claude Opus 4", "claude-opus-4-20250514", :packaged},
       {"Claude Sonnet 4.6", "claude-sonnet-4-6", :packaged},
       {"Claude Sonnet 4", "claude-sonnet-4-20250514", :packaged},
       {"Claude Haiku 4.5", "claude-haiku-4-5-20251001", :packaged}
     ]
   }},
  {:openrouter,
   %{
     env_key_name: "openrouterKeyValue",
     display_name: "OpenRouter",
     max_image_dimension: nil,
     llm_db_provider: [],
     default_model: "google/gemini-3-flash-preview",
     models: [
       {"GPT-5.5", "openai/gpt-5.5", :packaged},
       {"GPT-5.5 Pro", "openai/gpt-5.5-pro", :packaged},
       {"GPT-5.4", "openai/gpt-5.4", :packaged},
       {"GPT-5.4 Pro", "openai/gpt-5.4-pro", :packaged},
       {"GPT-5.3 Codex", "openai/gpt-5.3-codex", :packaged},
       # --------------
       {"Claude Opus 4.8", "anthropic/claude-opus-4.8", :packaged},
       {"Claude Opus 4.8 Fast", "anthropic/claude-opus-4.8-fast", :packaged},
       {"Claude Opus 4.7", "anthropic/claude-opus-4.7", :packaged},
       {"Claude Opus 4.7 Fast", "anthropic/claude-opus-4.7-fast", :packaged},
       {"Claude Sonnet Latest", "anthropic/claude-sonnet-latest", :packaged},
       {"Claude Haiku Latest", "anthropic/claude-haiku-latest", :packaged},
       # --------------
       {"Gemini 3.1 Pro Preview", "google/gemini-3.1-pro-preview", :packaged},
       {"Gemini Flash Latest", "~google/gemini-flash-latest", :packaged},
       # --------------
       {"Kimi Latest", "~moonshotai/kimi-latest", :packaged},
       {"MiniMax M2.7", "minimax/minimax-m2.7", :packaged}
     ]
   }},
  {:fireworks_ai,
   %{
     env_key_name: "fireworksKeyValue",
     display_name: "Fireworks AI",
     max_image_dimension: nil,
     llm_db_provider: [],
     default_model: "accounts/fireworks/routers/kimi-k2p6-turbo",
     models: [
       {"Kimi K2.6 Turbo", "accounts/fireworks/routers/kimi-k2p6-turbo", :packaged}
     ]
   }},
  {:nvidia,
   %{
     env_key_name: "nvidiaKeyValue",
     display_name: "NVIDIA",
     max_image_dimension: nil,
     llm_db_provider: [],
     default_model: "moonshotai/kimi-k2.6",
     models: [
       {"Kimi K2.6", "moonshotai/kimi-k2.6",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 262_144, output: 65_536},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"DeepSeek V4 Flash", "deepseek-ai/deepseek-v4-flash", :packaged},
       {"MiniMax M2.7", "minimaxai/minimax-m2.7", :packaged},
       {"Qwen3 Coder 480B", "qwen/qwen3-coder-480b-a35b-instruct", :packaged}
     ]
   }},
  {:google,
   %{
     env_key_name: nil,
     display_name: "Google",
     max_image_dimension: nil,
     llm_db_provider: [],
     models: []
   }},
  {:xai,
   %{
     env_key_name: nil,
     display_name: "xAI",
     max_image_dimension: nil,
     llm_db_provider: [],
     models: []
   }}
]

config :frontman_server, :providers, providers
