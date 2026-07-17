# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Agents do
  @moduledoc """
  Product agent catalog boundary.
  """

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts, FrontmanServer.Frameworks],
    exports: [Agent]

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Agents.Agent
  alias FrontmanServer.Agents.SystemPrompt

  def list_agents(%Scope{}) do
    config()
    |> Keyword.fetch!(:agents)
    |> Enum.map(&Agent.new!/1)
    |> resolve_catalog!()
  end

  @doc "Asserts the current global catalog and referenced agent IDs."
  def resolve_catalog!(active_agents, referenced_agent_ids \\ [])
      when is_list(active_agents) and is_list(referenced_agent_ids) do
    agent_ids = agent_ids!(active_agents)
    Enum.each(referenced_agent_ids, &Map.fetch!(agent_ids, &1))
    active_agents
  end

  def get_agent(%Scope{} = scope, agent_id) when is_binary(agent_id) do
    case Enum.find(list_agents(scope), &(&1.id == agent_id)) do
      %Agent{} = agent -> {:ok, agent}
      nil -> {:error, :unknown_agent}
    end
  end

  def resolve_agent_id(%Scope{}, nil), do: {:error, :missing_agent}
  def resolve_agent_id(%Scope{}, ""), do: {:error, :missing_agent}

  def resolve_agent_id(%Scope{} = scope, agent_id) when is_binary(agent_id) do
    case get_agent(scope, agent_id) do
      {:ok, agent} -> {:ok, agent.id}
      {:error, :unknown_agent} -> {:error, :unknown_agent}
    end
  end

  def default_agent_id(%Scope{} = scope) do
    agent_id = config() |> Keyword.fetch!(:default_agent_id)
    {:ok, %Agent{id: id}} = get_agent(scope, agent_id)
    id
  end

  def tool_policy(%Agent{} = agent), do: agent.tools

  def system_prompt(%Agent{} = agent, context) when is_map(context) do
    SystemPrompt.compose(agent, context)
  end

  defp agent_ids!(agents) do
    Enum.reduce(agents, %{}, fn %Agent{id: id} = agent, agents_by_id ->
      false = Map.has_key?(agents_by_id, id)
      Map.put(agents_by_id, id, agent)
    end)
  end

  defp config do
    Application.fetch_env!(:frontman_server, __MODULE__)
  end
end
