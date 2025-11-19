defmodule FrontmanServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FrontmanServerWeb.Telemetry,
      FrontmanServer.Repo,
      {DNSCluster, query: Application.get_env(:frontman_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FrontmanServer.PubSub},
      # Registry for task lookup
      {Registry, keys: :unique, name: FrontmanServer.TaskRegistry},
      # Registry for agent lookup
      {Registry, keys: :unique, name: FrontmanServer.AgentRegistry},
      # DynamicSupervisor for tasks
      {DynamicSupervisor, name: FrontmanServer.TaskSupervisor, strategy: :one_for_one},
      # DynamicSupervisor for agents
      {DynamicSupervisor, name: FrontmanServer.AgentSupervisor, strategy: :one_for_one},
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
