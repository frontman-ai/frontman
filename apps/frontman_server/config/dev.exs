import Config

# Mark environment for runtime checks
config :frontman_server, env: :dev

config :req_llm, receive_timeout: 600_000

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

# Watch static and templates for browser reloading.
config :frontman_server, FrontmanServerWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/frontman_server_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :frontman_server, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

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

# OpenTelemetry - configured in runtime.exs based on env vars
