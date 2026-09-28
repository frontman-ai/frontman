import Config

config :frontman_server, env: :e2e

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

config :logger, level: :info

config :frontman_server, dev_routes: true

config :frontman_server, :stripe,
  api_base_url: "http://127.0.0.1:1/v1",
  secret_key: "e2e-unused-key",
  webhook_secret: "e2e-unused-webhook-secret",
  monthly_price_id: "price_e2e_monthly",
  yearly_price_id: "price_e2e_yearly",
  trial_days: 14

config :workos, WorkOS.Client,
  api_key: "sk_test_workos_e2e",
  client_id: "client_test_workos_e2e"

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :task_id, :pid, :reason, :user_id, :user_name]

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

config :swoosh, :api_client, false

config :frontman_server, FrontmanServer.Mailer, api_key: "re_dev_placeholder"
