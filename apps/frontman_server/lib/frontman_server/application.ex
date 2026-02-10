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

    children = [
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
    ]

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
end
