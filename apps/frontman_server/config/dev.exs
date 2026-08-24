import Config

config :frontman_server,
  env: :dev,
  llm_wire_tap_enabled: true

config :frontman_server, FrontmanServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "frontman_server_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :frontman_server, FrontmanServerWeb.Endpoint,
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

config :frontman_server, FrontmanServerWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/frontman_server_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]

config :frontman_server, dev_routes: true

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :logger, level: :info

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

config :req_llm,
  telemetry: [payloads: :raw],
  debug: true

config :swoosh, :api_client, false

config :frontman_server, FrontmanServer.Mailer, api_key: "re_dev_placeholder"
