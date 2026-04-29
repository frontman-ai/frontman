# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :frontman_server, :scopes,
  user: [
    default: true,
    module: FrontmanServer.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: FrontmanServer.Test.Fixtures.Accounts,
    test_setup_helper: :register_and_log_in_user
  ]

config :req_llm,
  receive_timeout: 150_000,
  custom_providers: [FrontmanServer.Providers.Fireworks],
  # Override default Finch pool (8 connections) to handle concurrent LLM streams.
  # See https://github.com/frontman-ai/frontman/issues/428
  finch: [
    name: ReqLLM.Finch,
    pools: %{
      :default => [
        protocols: [:http1],
        # 1 connection per pool × 32 pools = 32 concurrent connections.
        # Increased from default count: 8 to prevent pool exhaustion under
        # concurrent agent executions + title generation.
        size: 1,
        count: 32
      ]
    }
  ]

config :frontman_server,
  ecto_repos: [FrontmanServer.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  # Default usage limit for server-provided API keys
  user_key_usage_limit: 10,
  # Max time to wait for the next LLM stream chunk before declaring a stall.
  # Anthropic ping keepalives now flow through as meta chunks, resetting this
  # timer during long-thinking requests (see issue #731).
  stream_stall_timeout_ms: 60_000,
  # Max output tokens for LLM responses. Increase to support long file writes.
  # Sonnet 4.5 supports up to 64K output tokens.
  llm_max_tokens: 64_000

# Configures the endpoint
config :frontman_server, FrontmanServerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FrontmanServerWeb.ErrorHTML, json: FrontmanServerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FrontmanServer.PubSub,
  live_view: [signing_salt: "GY0a1G8X"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :frontman_server, FrontmanServer.Mailer,
  adapter: Swoosh.Adapters.Local,
  contacts_url: "https://api.resend.com/contacts",
  segment_id: "974ede17-1b25-4e48-a71d-6d5f0923f402"

# Signup workers — disabled by default, enabled in prod and test.
config :frontman_server, FrontmanServer.Workers.SendWelcomeEmail, enabled: false
config :frontman_server, FrontmanServer.Workers.SyncResendContact, enabled: false
config :frontman_server, FrontmanServer.Workers.NotifyDiscordNewUser, enabled: false

# Oban background job processing (Postgres-backed)
config :frontman_server, Oban,
  repo: FrontmanServer.Repo,
  queues: [default: 10, mailers: 5, notifications: 5]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  frontman_server: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  browser_test: [
    args:
      ~w(js/browser-test.js --bundle --target=es2022 --format=esm --outdir=../priv/static/browser-test),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" => [
        Path.expand("../assets/node_modules", __DIR__),
        Path.expand("../deps", __DIR__)
      ]
    }
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  frontman_server: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :task_id, :pid, :reason]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Custom model definitions for models not yet in the packaged LLMDB catalog.
# These get merged into the snapshot at startup — existing models are untouched.
config :llm_db,
  custom: %{
    openrouter: [
      models: %{
        "anthropic/claude-opus-4.6" => %{
          name: "Claude Opus 4.6",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 200_000, output: 32_000},
          modalities: %{input: [:text, :image, :pdf], output: [:text]}
        },
        "openai/gpt-5.5" => %{
          name: "GPT-5.5",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        },
        "openai/gpt-5.4-pro" => %{
          name: "GPT-5.4 Pro",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        },
        "openai/gpt-5.4" => %{
          name: "GPT-5.4",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        },
        "openai/gpt-5.3-codex" => %{
          name: "GPT-5.3 Codex",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 400_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        },
        "moonshotai/kimi-k2.5" => %{
          name: "Kimi K2.5",
          capabilities: %{
            chat: true,
            streaming: %{text: true, tool_calls: false},
            tools: %{enabled: true}
          },
          limits: %{context: 131_072, output: 32_768},
          modalities: %{input: [:text], output: [:text]}
        },
        "minimax/minimax-m2.5" => %{
          name: "Minimax M2.5",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_192, output: 1_000_192},
          modalities: %{input: [:text, :image], output: [:text]}
        }
      }
    ],
    fireworks: [
      name: "Fireworks AI",
      base_url: "https://api.fireworks.ai/inference/v1",
      env: ["FIREWORKS_API_KEY"],
      doc: "https://docs.fireworks.ai/firepass",
      models: %{
        "accounts/fireworks/routers/kimi-k2p5-turbo" => %{
          name: "Kimi K2.5 Turbo",
          family: "kimi-thinking",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 256_000, output: 256_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }
      }
    ],
    anthropic: [
      models: %{
        "claude-opus-4-6" => %{
          name: "Claude Opus 4.6",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 200_000, output: 64_000},
          modalities: %{input: [:text, :image, :pdf], output: [:text]}
        }
      }
    ],
    openai: [
      models: %{
        "gpt-5.5" => %{
          name: "GPT-5.5",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        },
        "gpt-5.4" => %{
          name: "GPT-5.4",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 1_000_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        },
        "gpt-5.3-codex" => %{
          name: "GPT-5.3 Codex",
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            streaming: %{text: true, tool_calls: true},
            tools: %{enabled: true}
          },
          limits: %{context: 400_000, output: 128_000},
          modalities: %{input: [:text, :image], output: [:text]}
        }
      }
    ]
  }

# Centralised provider registry — single source of truth for every supported
# LLM provider.  The runtime modules (Registry, runtime.exs) derive their
# behaviour from this map instead of maintaining separate hard-coded lists.
#
# Fields:
#   :config_key          – Application.get_env atom for the server API key
#   :env_var             – OS environment variable name (used by runtime.exs)
#   :env_key_name        – metadata key the client sends for project-level keys (nil = n/a)
#   :display_name        – human-readable label for the UI
#   :priority            – display ordering (lower = shown first)
#   :oauth_provider      – provider string for OAuth token lookup (nil = no OAuth)
#   :env_key_param       – query param the client sends to signal it has an env key (nil = n/a)
#   :max_image_dimension – hard pixel-per-side limit (nil = provider auto-resizes)
config :frontman_server, :providers, %{
  "openai" => %{
    config_key: :openai_api_key,
    env_var: "OPENAI_API_KEY",
    env_key_name: nil,
    display_name: "ChatGPT Pro/Plus",
    priority: 10,
    oauth_provider: "chatgpt",
    env_key_param: nil,
    max_image_dimension: nil
  },
  "anthropic" => %{
    config_key: :anthropic_api_key,
    env_var: "ANTHROPIC_API_KEY",
    env_key_name: "anthropicKeyValue",
    display_name: "Anthropic (Claude Pro/Max)",
    priority: 20,
    oauth_provider: "anthropic",
    env_key_param: "hasAnthropicEnvKey",
    # Anthropic hard-rejects images > 8000px per side; 7680 leaves margin.
    max_image_dimension: 7680
  },
  "openrouter" => %{
    config_key: :openrouter_api_key,
    env_var: "OPENROUTER_API_KEY",
    env_key_name: "openrouterKeyValue",
    display_name: "OpenRouter",
    priority: 30,
    oauth_provider: nil,
    env_key_param: "hasEnvKey",
    max_image_dimension: nil
  },
  "fireworks" => %{
    config_key: :fireworks_api_key,
    env_var: "FIREWORKS_API_KEY",
    env_key_name: "fireworksKeyValue",
    display_name: "Fireworks AI",
    priority: 35,
    oauth_provider: nil,
    env_key_param: nil,
    max_image_dimension: nil
  },
  "google" => %{
    config_key: :google_api_key,
    env_var: "GOOGLE_API_KEY",
    env_key_name: nil,
    display_name: "Google",
    priority: 40,
    oauth_provider: nil,
    env_key_param: nil,
    max_image_dimension: nil
  },
  "xai" => %{
    config_key: :xai_api_key,
    env_var: "XAI_API_KEY",
    env_key_name: nil,
    display_name: "xAI",
    priority: 50,
    oauth_provider: nil,
    env_key_param: nil,
    max_image_dimension: nil
  }
}

config :frontman_server, FrontmanServer.Tasks.MessageOptimizer,
  enabled: true,
  tool_result_strip_keys: ["start_line", "lines_returned", "total_lines"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
