import Config

# Mark environment for runtime checks
config :frontman_server, env: :dev

# Configure your database
# For DevPod: post-create.sh updates hostname to the Docker gateway IP
# For local dev: uses localhost
config :frontman_server, FrontmanServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "frontman_server_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
# E2E mode: HTTPS on port 4002, separate database, no watchers.
# Uses the same mkcert certificates as normal dev (covers localhost).
# Activated by setting E2E=true in the environment.
if System.get_env("E2E") do
  config :frontman_server, FrontmanServer.Repo,
    database: System.get_env("DB_NAME") || "frontman_server_e2e"

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
else
  config :frontman_server, FrontmanServerWeb.Endpoint,
    # Binding to 0.0.0.0 allows access from containers/proxies
    # URL host can be overridden via PHX_HOST env var for remote development
    url: [
      host: System.get_env("PHX_HOST") || "frontman.local",
      port: String.to_integer(System.get_env("PHX_URL_PORT") || "4000"),
      scheme: "https"
    ],
    https: [
      ip: {0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000"),
      cipher_suite: :strong,
      keyfile: Path.expand("../../../.certs/frontman.local-key.pem", __DIR__),
      certfile: Path.expand("../../../.certs/frontman.local.pem", __DIR__)
    ],
    check_origin: false,
    code_reloader: true,
    debug_errors: true,
    secret_key_base: "NBTbU2SqLo+ghhs3jQiZAjRrQKhim/x/HXSbx49mBnt4pSvEkjTYYrj+prSCInNO",
    watchers: [
      esbuild: {Esbuild, :install_and_run, [:frontman_server, ~w(--sourcemap=inline --watch)]},
      esbuild: {Esbuild, :install_and_run, [:browser_test, ~w(--sourcemap=inline --watch)]},
      tailwind: {Tailwind, :install_and_run, [:frontman_server, ~w(--watch)]}
    ]
end

# Watch static and templates for browser reloading (not needed in E2E mode).
unless System.get_env("E2E") do
  config :frontman_server, FrontmanServerWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
        ~r"priv/gettext/.*(po)$",
        ~r"lib/frontman_server_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
      ]
    ]
end

# Enable dev routes for dashboard and mailbox
config :frontman_server, dev_routes: true

# Include metadata and timestamps in development logs for verbose debugging
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :task_id, :pid, :reason]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Placeholder Resend API key for dev — workers will call real Resend and get a 401,
# which Oban handles as a retryable error. Harmless in dev.
config :frontman_server, FrontmanServer.Mailer, api_key: "re_dev_placeholder"

# OpenTelemetry - configured in runtime.exs based on env vars
