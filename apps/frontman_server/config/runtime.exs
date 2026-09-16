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
  case env!(env_var_name, :string?, nil) do
    nil -> default_value
    raw_value -> strict_boolean!.(env_var_name, raw_value)
  end
end

if env_boolean.("PHX_SERVER", false) do
  config :frontman_server, FrontmanServerWeb.Endpoint, server: true
end

config :frontman_server, cloak_key: env!("CLOAK_KEY", :string!)

if config_env() in [:dev, :prod] do
  config :workos, WorkOS.Client,
    api_key: env!("WORKOS_API_KEY", :string!),
    client_id: env!("WORKOS_CLIENT_ID", :string!)
end

if config_env() in [:dev, :test, :e2e] do
  db_host = env!("DB_HOST", :string, "localhost")

  db_name = env!("DB_NAME", :string?, nil)

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
  discord_new_users_webhook_url = env!("DISCORD_NEW_USERS_WEBHOOK_URL", :string!)
  discord_task_summaries_webhook_url = env!("DISCORD_TASK_SUMMARIES_WEBHOOK_URL", :string!)
  resend_api_key = env!("RESEND_API_KEY", :string!)

  config :frontman_server, FrontmanServer.Workers.SendWelcomeEmail, enabled: true

  config :frontman_server, FrontmanServer.Workers.SyncResendContact, enabled: true

  config :frontman_server, FrontmanServer.Workers.NotifyDiscordNewUser,
    enabled: true,
    webhook_url: discord_new_users_webhook_url

  config :frontman_server, FrontmanServer.Workers.SendAgentFeedbackToDiscord,
    enabled: true,
    webhook_url: discord_task_summaries_webhook_url

  database_url = env!("DATABASE_URL", :string!)

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
    {:pool_size, env!("POOL_SIZE", :integer, 10)},
    {:socket_options, maybe_ipv6}
    | ssl_config
  ]

  secret_key_base = env!("SECRET_KEY_BASE", :string!)

  host = env!("PHX_HOST", :string, "example.com")
  port = env!("PORT", :integer, 4000)

  http_shutdown_timeout_ms = env!("HTTP_SHUTDOWN_TIMEOUT_MS", :integer, 30_000)

  config :frontman_server, :dns_cluster_query, env!("DNS_CLUSTER_QUERY", :string?, nil)

  check_origin = ["https://#{host}", "https://*.#{host}"]

  config :frontman_server, FrontmanServerWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port,
      thousand_island_options: [shutdown_timeout: http_shutdown_timeout_ms]
    ],
    check_origin: check_origin,
    secret_key_base: secret_key_base

  config :frontman_server, FrontmanServer.Mailer,
    adapter: Swoosh.Adapters.Resend,
    api_key: resend_api_key
end
