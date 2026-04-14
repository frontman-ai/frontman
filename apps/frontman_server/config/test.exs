import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :frontman_server, FrontmanServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database:
    "frontman_server_test#{System.get_env("MIX_TEST_PARTITION")}#{System.get_env("MIX_TEST_DB_SUFFIX")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :frontman_server, FrontmanServerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "G/GaF+myr6UzSNKYFjTUkCovxv4WghMsXaq4S3O275rp8dLDSEvwkXAn5kbkvUJn",
  server: false

# In test we don't send emails
config :frontman_server, FrontmanServer.Mailer,
  adapter: Swoosh.Adapters.Test,
  api_key: "re_test_key"

# Oban: inline execution for tests (no async workers)
config :frontman_server, Oban, testing: :manual

# Discord webhook URL for test assertions
config :frontman_server, discord_new_users_webhook_url: "https://discord.test/webhook"

# Enable signup workers in test so assertions work
config :frontman_server, FrontmanServer.Workers.SendWelcomeEmail, enabled: true
config :frontman_server, FrontmanServer.Workers.SyncResendContact, enabled: true
config :frontman_server, FrontmanServer.Workers.NotifyDiscordNewUser, enabled: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Only print warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# LLM Configuration
config :frontman_server,
  anthropic_api_key: "sk-ant-test-key",
  openai_api_key: "sk-proj-test-key",
  # Test key for Cloak encryption (generated with :crypto.strong_rand_bytes(32) |> Base.encode64())
  cloak_key: "dGVzdGtleXRlc3RrZXl0ZXN0a2V5dGVzdGtleTEyMzQ="

# OpenTelemetry - disable in tests
config :opentelemetry,
  span_processor: :simple,
  traces_exporter: :none

# Sentry - enable test mode, disable dedup to avoid test interference
config :sentry,
  test_mode: true,
  dedup_events: false
