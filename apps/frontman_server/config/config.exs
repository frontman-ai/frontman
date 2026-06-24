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

config :frontman_server,
  ecto_repos: [FrontmanServer.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  # Max time to wait for the next LLM stream chunk before declaring a stall.
  # Anthropic ping keepalives now flow through as meta chunks, resetting this
  # timer during long-thinking requests (see issue #731).
  stream_stall_timeout_ms: 60_000,
  # Max output tokens for LLM responses. Increase to support long file writes.
  # Sonnet 4.5 supports up to 64K output tokens.
  llm_max_tokens: 64_000

config :frontman_server, :backend_tools, [
  FrontmanServer.Tools.GetToolResult,
  FrontmanServer.Tools.TodoWrite,
  FrontmanServer.Tools.WebFetch
]

config :frontman_server, FrontmanServer.Providers.OpenAIOAuth,
  client_id: "app_EMoamEEZ73f0CkXaXp7hrann",
  issuer: "https://auth.openai.com"

config :frontman_server, FrontmanServer.Providers.AnthropicOAuth,
  client_id: "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
  auth_url: "https://claude.ai/oauth/authorize",
  token_url: "https://console.anthropic.com/v1/oauth/token",
  redirect_uri: "https://console.anthropic.com/oauth/code/callback",
  scopes: "org:create_api_key user:profile user:inference"

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

config :logger, :default_formatter,
  format: "\n$time [$level] $metadata$message\n",
  metadata: [:request_id, :module, :function, :reason, :task_id, :user_id, :user_name]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

import_config "providers.exs"

providers = Keyword.fetch!(read_config(:frontman_server), :providers)

llm_db_custom =
  providers
  |> Enum.filter(fn {_provider, provider_config} -> provider_config.models != [] end)
  |> Enum.map(fn {provider, provider_config} ->
    models =
      provider_config
      |> Map.fetch!(:models)
      |> Enum.reject(fn {_name, _value, metadata} -> metadata == :packaged end)
      |> Map.new(fn {name, value, metadata} -> {value, Map.put(metadata, :name, name)} end)

    llm_db_provider =
      provider_config
      |> Map.fetch!(:llm_db_provider)
      |> Keyword.put(:models, models)

    {provider, llm_db_provider}
  end)
  |> Map.new()

config :req_llm,
  receive_timeout: 150_000,
  # Override default Finch pool (8 connections) to handle concurrent LLM streams.
  # See https://github.com/frontman-ai/frontman/issues/428
  finch: [
    name: ReqLLM.Finch,
    pools: %{
      :default => [
        protocols: [:http1],
        size: 1,
        count: 32
      ]
    }
  ]

config :llm_db, custom: llm_db_custom

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
