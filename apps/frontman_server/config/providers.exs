import Config

# Provider config. Client model options and custom LLMDB model metadata are
# derived from this ordered list.
#
# Fields:
#   :env_key_name        – metadata key the client sends for project-level keys (nil = n/a)
#   :display_name        – human-readable label for the UI
#   :max_image_dimension – hard pixel-per-side limit (nil = provider auto-resizes)
#   :codex_base_url      - OpenAI OAuth Codex API endpoint (OpenAI only)
# Model tuple shape: {display_name, model_id, llm_db_metadata | :packaged}
providers = [
  {:openai,
   %{
     env_key_name: nil,
     display_name: "OpenAI",
     max_image_dimension: nil,
     codex_base_url: "https://chatgpt.com/backend-api/codex",
     llm_db_provider: [],
     default_model: "gpt-5.5",
     models: [
       {"GPT-5.5", "gpt-5.5",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"GPT-5.4", "gpt-5.4",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"GPT-5.4 Mini", "gpt-5.4-mini", :packaged},
       {"GPT-5.3 Codex", "gpt-5.3-codex",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 400_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }}
     ]
   }},
  {:anthropic,
   %{
     env_key_name: "anthropicKeyValue",
     display_name: "Anthropic (Claude Pro/Max)",
     # Anthropic hard-rejects images > 8000px per side; 7680 leaves margin.
     max_image_dimension: 7680,
     llm_db_provider: [],
     default_model: "claude-sonnet-4-5",
     models: [
       {"Claude Opus 4.6", "claude-opus-4-6",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 200_000, output: 64_000},
          modalities: %{input: [:text, :image, :pdf], output: [:text]}
        }},
       {"Claude Sonnet 4.5", "claude-sonnet-4-5", :packaged},
       {"Claude Opus 4.5", "claude-opus-4-5", :packaged},
       {"Claude Haiku 4.5", "claude-haiku-4-5", :packaged},
       {"Claude Sonnet 4", "claude-sonnet-4-20250514", :packaged},
       {"Claude Opus 4", "claude-opus-4-20250514", :packaged}
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
       {"GPT-5.5", "openai/gpt-5.5",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"GPT-5.4 Pro", "openai/gpt-5.4-pro",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"GPT-5.4", "openai/gpt-5.4",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"GPT-5.3 Codex", "openai/gpt-5.3-codex",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 400_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"GPT-4.1", "openai/gpt-4.1",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 32_768},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"o3", "openai/o3", :packaged},
       {"o4-mini", "openai/o4-mini", :packaged},
       {"Claude Opus 4.6", "anthropic/claude-opus-4.6",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 200_000, output: 32_000},
          modalities: %{input: [:text, :image, :pdf], output: [:text]}
        }},
       {"Claude Sonnet 4.5", "anthropic/claude-sonnet-4.5", :packaged},
       {"Claude Opus 4.5", "anthropic/claude-opus-4.5", :packaged},
       {"Claude Haiku 4.5", "anthropic/claude-haiku-4.5", :packaged},
       {"Gemini 3 Pro Preview", "google/gemini-3-pro-preview",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_048_576, output: 65_536},
          modalities: %{input: [:text, :image], output: [:text]}
        }},
       {"Gemini 3 Flash Preview", "google/gemini-3-flash-preview", :packaged},
       {"Gemini 2.5 Pro", "google/gemini-2.5-pro", :packaged},
       {"Kimi K2.6", "moonshotai/kimi-k2.6", :packaged},
       {"MiniMax M2.7", "minimax/minimax-m2.7", :packaged},
       {"Kimi K2.5", "moonshotai/kimi-k2.5",
        %{
          capabilities: %{
            chat: true,
            streaming: %{text: true, tool_calls: false},
            tools: %{enabled: true}
          },
          limits: %{context: 131_072, output: 32_768},
          modalities: %{input: [:text], output: [:text]}
        }},
       {"Minimax M2.5", "minimax/minimax-m2.5",
        %{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_192, output: 1_000_192},
          modalities: %{input: [:text, :image], output: [:text]}
        }}
     ]
   }},
  {:fireworks,
   %{
     env_key_name: "fireworksKeyValue",
     display_name: "Fireworks AI",
     max_image_dimension: nil,
     llm_db_provider: [
       name: "Fireworks AI",
       base_url: "https://api.fireworks.ai/inference/v1",
       env: ["FIREWORKS_API_KEY"],
       doc: "https://docs.fireworks.ai/firepass"
     ],
     default_model: "accounts/fireworks/routers/kimi-k2p5-turbo",
     models: [
       {"Kimi K2.5 Turbo", "accounts/fireworks/routers/kimi-k2p5-turbo",
        %{
          family: "kimi-thinking",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 256_000, output: 256_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }}
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
