import Config
import Dotenvy

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")

source!([
  Path.absname(".env", env_dir_prefix),
  Path.absname(".#{config_env()}.env", env_dir_prefix),
  Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
  System.get_env()
])

if System.get_env("PHX_SERVER") do
  config :frontman_server, FrontmanServerWeb.Endpoint, server: true
end

# Cloak encryption key for API keys at rest (required)
config :frontman_server, cloak_key: env!("CLOAK_KEY", :string!)

# LLM API keys - loaded at runtime from environment
if config_env() in [:dev, :test] do
  config :frontman_server,
    anthropic_api_key: env!("ANTHROPIC_API_KEY", :string, nil),
    google_api_key: env!("GOOGLE_API_KEY", :string, nil),
    xai_api_key: env!("XAI_API_KEY", :string, nil),
    openrouter_api_key: env!("OPENROUTER_API_KEY", :string, nil),
    openai_api_key: env!("OPENAI_API_KEY", :string, nil)
end

# WorkOS configuration for OAuth (GitHub, Google)
config :workos, WorkOS.Client,
  api_key: env!("WORKOS_API_KEY", :string, nil),
  client_id: env!("WORKOS_CLIENT_ID", :string, nil)

# OpenTelemetry configuration
# Arize export enabled if both ARIZE_API_KEY and ARIZE_SPACE_ID are set
# Optional in all environments - when not set, tracing export is disabled
{arize_api_key, arize_space_id} =
  {env!("ARIZE_API_KEY", :string, nil), env!("ARIZE_SPACE_ID", :string, nil)}

if arize_api_key && arize_space_id do
  arize_endpoint =
    env!("ARIZE_COLLECTOR_ENDPOINT", :string, "https://otlp.eu-west-1a.arize.com")

  arize_project = env!("ARIZE_PROJECT_NAME", :string, "frontman")

  config :opentelemetry,
    span_processor: :batch,
    traces_exporter: :otlp

  config :opentelemetry, :resource, [
    {"service.name", "frontman-server"},
    {"service.version", "0.0.1"},
    {"deployment.environment", to_string(config_env())},
    {"project.name", arize_project},
    {"model_id", "frontman"},
    {"model_version", "0.0.1"}
  ]

  config :opentelemetry_exporter,
    otlp_protocol: :http_protobuf,
    otlp_endpoint: arize_endpoint,
    otlp_headers: [
      {"space_id", arize_space_id},
      {"api_key", arize_api_key}
    ]
else
  # No Arize - disable export, basic resource only
  config :opentelemetry, traces_exporter: :none

  config :opentelemetry, :resource, [
    {"service.name", "frontman-server"},
    {"service.version", "0.0.1"},
    {"deployment.environment", to_string(config_env())}
  ]
end

# Dev/Test: Allow DB_HOST override for container development (e.g., DevPod)
# The docker bridge gateway IP (172.17.0.1) is used to connect from container to host PostgreSQL
if config_env() in [:dev, :test] do
  db_host = env!("DB_HOST", :string, "localhost")

  if db_host != "localhost" do
    config :frontman_server, FrontmanServer.Repo, hostname: db_host
  end
end

if config_env() == :prod do
  config :sentry,
    dsn:
      "https://442ae992e5a5ccfc42e6910220aeb2a9@o4510512511320064.ingest.de.sentry.io/4510512546185296",
    environment_name: config_env(),
    release: "frontman_server@#{Application.spec(:frontman_server, :vsn) || "no_vsn"}",
    enable_source_code_context: true,
    root_source_code_paths: [File.cwd!()],
    tags: %{service: "frontman-server"}

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # SSL can be disabled for local PostgreSQL (DATABASE_SSL=false)
  use_ssl = System.get_env("DATABASE_SSL", "true") not in ~w(false 0)

  ssl_config =
    if use_ssl do
      [ssl: true, ssl_opts: [verify: :verify_none]]
    else
      []
    end

  config :frontman_server, FrontmanServer.Repo, [
    {:url, database_url},
    {:pool_size, String.to_integer(System.get_env("POOL_SIZE") || "10")},
    {:socket_options, maybe_ipv6}
    | ssl_config
  ]

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :frontman_server, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :frontman_server, FrontmanServerWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :frontman_server, FrontmanServerWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :frontman_server, FrontmanServerWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :frontman_server, FrontmanServer.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
