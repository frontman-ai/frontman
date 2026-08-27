import Config
import Dotenvy

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")

source!([
  Path.absname(".env", env_dir_prefix),
  Path.absname(".#{config_env()}.env", env_dir_prefix),
  Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
  System.get_env()
])

truthy_env_values = ~w(1 true yes on)
falsy_env_values = ~w(0 false no off)
accepted_env_values = truthy_env_values ++ falsy_env_values

strict_boolean! = fn env_var_name, raw_value ->
  normalized_value = raw_value |> String.trim() |> String.downcase()

  cond do
    normalized_value in truthy_env_values ->
      true

    normalized_value in falsy_env_values ->
      false

    true ->
      raise Dotenvy.Error,
        message:
          "#{env_var_name} must be one of #{inspect(accepted_env_values)}; got: #{inspect(raw_value)}"
  end
end

env_boolean = fn env_var_name, default_value ->
  case env!(env_var_name, :string, :frontman_env_boolean_missing) do
    :frontman_env_boolean_missing ->
      default_value

    raw_value ->
      if String.trim(raw_value) == "" do
        default_value
      else
        strict_boolean!.(env_var_name, raw_value)
      end
  end
end

if env_boolean.("PHX_SERVER", false) do
  config :frontman_server, FrontmanServerWeb.Endpoint, server: true
end

config :frontman_server, cloak_key: env!("CLOAK_KEY", :string!)

config :workos, WorkOS.Client,
  api_key: env!("WORKOS_API_KEY", :string, nil),
  client_id: env!("WORKOS_CLIENT_ID", :string, nil)

if config_env() in [:dev, :test, :e2e] do
  db_host = env!("DB_HOST", :string, "localhost")

  db_name = env!("DB_NAME", :string, nil)

  repo_overrides = []

  repo_overrides =
    if db_host != "localhost" do
      [{:hostname, db_host} | repo_overrides]
    else
      repo_overrides
    end

  repo_overrides =
    if db_name do
      [{:database, db_name} | repo_overrides]
    else
      repo_overrides
    end

  if repo_overrides != [] do
    config :frontman_server, FrontmanServer.Repo, repo_overrides
  end
end

if config_env() == :prod do
  discord_new_users_webhook_url = env!("DISCORD_NEW_USERS_WEBHOOK_URL", :string, nil)
  resend_api_key = env!("RESEND_API_KEY", :string, nil)

  discord_notifications_enabled =
    is_binary(discord_new_users_webhook_url) and String.trim(discord_new_users_webhook_url) != ""

  resend_enabled = is_binary(resend_api_key) and String.trim(resend_api_key) != ""

  config :frontman_server,
    discord_new_users_webhook_url: discord_new_users_webhook_url

  config :frontman_server, FrontmanServer.Workers.SendWelcomeEmail, enabled: resend_enabled
  config :frontman_server, FrontmanServer.Workers.SyncResendContact, enabled: resend_enabled

  config :frontman_server, FrontmanServer.Workers.NotifyDiscordNewUser,
    enabled: discord_notifications_enabled

  config :sentry,
    dsn: env!("SENTRY_DSN", :string!),
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

  maybe_ipv6 = if env_boolean.("ECTO_IPV6", false), do: [:inet6], else: []

  use_ssl = env_boolean.("DATABASE_SSL", true)

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

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :frontman_server, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  check_origin = false

  config :frontman_server, FrontmanServerWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    check_origin: check_origin,
    secret_key_base: secret_key_base

  if resend_enabled do
    config :frontman_server, FrontmanServer.Mailer,
      adapter: Swoosh.Adapters.Resend,
      api_key: resend_api_key
  end
end
