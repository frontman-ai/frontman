import Config

# Mark environment for runtime checks
config :frontman_server, env: :e2e

# Configure your database
config :frontman_server, FrontmanServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "frontman_server_e2e",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :frontman_server, FrontmanServerWeb.Endpoint,
  url: [host: "localhost", port: 4002, scheme: "https"],
  https: [
    ip: {127, 0, 0, 1},
    port: 4002,
    cipher_suite: :strong,
    keyfile: Path.expand("../../../.certs/frontman.local-key.pem", __DIR__),
    certfile: Path.expand("../../../.certs/frontman.local.pem", __DIR__)
  ],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: "NBTbU2SqLo+ghhs3jQiZAjRrQKhim/x/HXSbx49mBnt4pSvEkjTYYrj+prSCInNO",
  server: true,
  watchers: [],
  live_reload: false

# Suppress debug-level noise in E2E (SQL queries, route errors, etc.)
config :logger, level: :info

# Keep dev routes available in E2E to match local development behavior.
config :frontman_server, dev_routes: true

# Include metadata and timestamps in logs.
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :task_id, :pid, :reason]

# Keep a higher stacktrace depth for easier local debugging.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster compilation.
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Placeholder Resend API key for E2E.
config :frontman_server, FrontmanServer.Mailer, api_key: "re_dev_placeholder"

# OpenTelemetry - configured in runtime.exs based on env vars
