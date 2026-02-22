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

    children =
      [
        FrontmanServerWeb.Telemetry,
        FrontmanServer.Repo,
        FrontmanServer.Vault,
        {DNSCluster, query: Application.get_env(:frontman_server, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: FrontmanServer.PubSub},
        # Registry for tracking agents and tool calls
        {Registry, keys: :unique, name: FrontmanServer.AgentRegistry},
        # Monitors task executions and broadcasts errors on crash
        FrontmanServer.Tasks.ExecutionMonitor,
        # TaskSupervisor for agent execution tasks
        {Task.Supervisor, name: FrontmanServer.TaskSupervisor},
        # Start to serve requests, typically the last entry
        FrontmanServerWeb.Endpoint
      ] ++ discord_notification_children()

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

  # Builds the child specs for Discord new-user notifications.
  # Returns [] when DISCORD_NEW_USERS_WEBHOOK_URL is not set.
  defp discord_notification_children do
    case Application.get_env(:frontman_server, :discord_new_users_webhook_url) do
      nil ->
        []

      webhook_url ->
        pg_opts = pg_notify_opts()

        [
          {Postgrex.Notifications, [name: FrontmanServer.PGNotifications] ++ pg_opts},
          {FrontmanServer.Notifications.Discord,
           webhook_url: webhook_url, notifications_pid: FrontmanServer.PGNotifications}
        ]
    end
  end

  # Extracts Postgrex connection options from the Repo config.
  # Handles both DATABASE_URL (prod) and individual keys (dev).
  defp pg_notify_opts do
    repo_config = Application.get_env(:frontman_server, FrontmanServer.Repo)

    case repo_config[:url] do
      url when is_binary(url) ->
        uri = URI.parse(url)

        {username, password} =
          case uri.userinfo do
            nil -> {nil, nil}
            info -> List.to_tuple(String.split(info, ":", parts: 2))
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
