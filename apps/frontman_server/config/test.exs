import Config

config :bcrypt_elixir, :log_rounds, 1

config :frontman_server, FrontmanServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database:
    "frontman_server_test#{System.get_env("MIX_TEST_PARTITION")}#{System.get_env("MIX_TEST_DB_SUFFIX")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :frontman_server, FrontmanServerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "G/GaF+myr6UzSNKYFjTUkCovxv4WghMsXaq4S3O275rp8dLDSEvwkXAn5kbkvUJn",
  server: false

config :frontman_server, FrontmanServer.Mailer,
  adapter: Swoosh.Adapters.Test,
  api_key: "re_test_key"

config :workos, WorkOS.Client,
  api_key: "sk_test_workos",
  client_id: "client_test_workos"

config :frontman_server, Oban, testing: :manual

config :frontman_server, discord_new_users_webhook_url: "https://discord.test/webhook"

config :frontman_server, FrontmanServer.Workers.SendWelcomeEmail, enabled: true
config :frontman_server, FrontmanServer.Workers.SyncResendContact, enabled: true
config :frontman_server, FrontmanServer.Workers.NotifyDiscordNewUser, enabled: true

config :swoosh, :api_client, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :frontman_server,
  llm_provider: FrontmanServer.Tasks.Execution.LLMProviderMock,
  cloak_key: "dGVzdGtleXRlc3RrZXl0ZXN0a2V5dGVzdGtleTEyMzQ="

config :frontman_server, FrontmanServer.Agents,
  default_agent_id: "test-planner",
  agents: [
    %{
      id: "test-frontman",
      name: "executor",
      display_name: "Executor",
      description: "Software engineering execution agent with full tool access.",
      color: "#985DF7",
      system: "Test executor system."
    },
    %{
      id: "test-planner",
      name: "planner",
      display_name: "Planner",
      description:
        "Read-only planning agent that prepares implementation plans for later execution.",
      color: "#F59E0B",
      system: "Test planner system.",
      tools: %{access: [:read]}
    }
  ]

config :frontman_server, :web_fetch_req_options,
  plug: {Req.Test, :web_fetch},
  retry_delay: fn _ -> 0 end,
  retry_log_level: false

config :frontman_server, FrontmanServer.Providers.AnthropicOAuth,
  req_options: [plug: {Req.Test, :anthropic_oauth}, retry: false]

config :frontman_server, FrontmanServer.Providers.OpenAIOAuth,
  req_options: [plug: {Req.Test, :openai_oauth}, retry: false]

config :sentry,
  test_mode: true,
  dedup_events: false
