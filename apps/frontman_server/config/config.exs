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
    test_data_fixture: FrontmanServer.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :frontman_server,
  ecto_repos: [FrontmanServer.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  # Default usage limit for server-provided API keys
  user_key_usage_limit: 10

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
config :frontman_server, FrontmanServer.Mailer, adapter: Swoosh.Adapters.Local

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
