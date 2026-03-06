defmodule FrontmanServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias FrontmanServer.Observability.ConsoleHandler
  alias FrontmanServer.Observability.OtelHandler
  alias FrontmanServer.Observability.SwarmOtelHandler

  @impl true
  def start(_type, _args) do
    # Setup telemetry -> OTEL span translation
    OtelHandler.setup()
    SwarmOtelHandler.setup()

    # Setup console telemetry logging in dev
    if Application.get_env(:frontman_server, :env) == :dev do
      ConsoleHandler.setup()
    end

    # Add Sentry logger handler to capture crashed process exceptions
    :logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{
      config: %{metadata: [:file, :line]}
    })

    :telemetry.attach(
      "finch-logger",
      [:finch, :request, :start],
      &FrontmanServer.FinchLogger.handle_event/4,
      nil
    )

    # Discord new-user signup alerts (PG LISTEN/NOTIFY → webhook) – prod only
    discord_children =
      if Application.get_env(:frontman_server, :discord_new_users_webhook_url) do
        [
          {Postgrex.Notifications, [name: FrontmanServer.PGNotifications] ++ pg_notify_opts()},
          {FrontmanServer.Notifications.Discord,
           webhook_url: Application.get_env(:frontman_server, :discord_new_users_webhook_url),
           channel: Application.get_env(:frontman_server, :discord_pg_channel),
           notifications_pid: FrontmanServer.PGNotifications}
        ]
      else
        []
      end

    children =
      [
        FrontmanServerWeb.Telemetry,
        FrontmanServer.Repo,
        FrontmanServer.Vault,
        {DNSCluster, query: Application.get_env(:frontman_server, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: FrontmanServer.PubSub},
        # Supervised agent execution (Registry + TaskSupervisor + ExecutionMonitor)
        {SwarmAi.Runtime, name: FrontmanServer.AgentRuntime},
        # Registry for MCP tool call result routing (separate from agent execution tracking)
        {Registry, keys: :unique, name: FrontmanServer.ToolCallRegistry},
        # Oban background job processing (email delivery, contact sync, etc.)
        {Oban, Application.fetch_env!(:frontman_server, Oban)},
        # General-purpose TaskSupervisor for non-agent background tasks (title generation, etc.)
        {Task.Supervisor, name: FrontmanServer.TaskSupervisor},
        # Start to serve requests, typically the last entry
        FrontmanServerWeb.Endpoint
      ] ++ discord_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FrontmanServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FrontmanServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Extracts Postgrex connection options from the Repo config.
  # Handles both DATABASE_URL (prod) and individual keys (dev).
  defp pg_notify_opts do
    repo_config = Application.get_env(:frontman_server, FrontmanServer.Repo)

    case repo_config[:url] do
      url when is_binary(url) ->
        uri = URI.parse(url)

        # Intentionally crashes if userinfo is present but missing a password —
        # DATABASE_URL must always include user:password credentials.
        {username, password} =
          case uri.userinfo do
            nil ->
              {nil, nil}

            info ->
              [user, pass] = String.split(info, ":", parts: 2)
              {URI.decode(user), URI.decode(pass)}
          end

        [
          hostname: uri.host,
          port: uri.port || 5432,
          username: username,
          password: password,
          database: String.trim_leading(uri.path || "/", "/")
        ] ++ Keyword.take(repo_config, [:ssl, :ssl_opts, :socket_options])

      _ ->
        Keyword.take(repo_config, [
          :hostname,
          :port,
          :username,
          :password,
          :database,
          :ssl,
          :ssl_opts,
          :socket_options
        ])
    end
  end
end
