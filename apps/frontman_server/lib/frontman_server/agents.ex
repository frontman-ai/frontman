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
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  def list_agents(%Scope{}) do
    config()
    |> Keyword.fetch!(:agents)
    |> Enum.map(&Agent.new!/1)
  end

  @doc "Returns stable active-first union of current and historical agent definitions."
  def resolve_catalog(active_agents, turn_rows, referenced_agent_ids \\ [])
      when is_list(active_agents) and is_list(turn_rows) and is_list(referenced_agent_ids) do
    with {:ok, active} <- append_agents(active_agents, %{ordered: [], by_id: %{}}),
         {:ok, catalog} <- append_turn_agents(turn_rows, active),
         :ok <- validate_referenced_agents(catalog.by_id, referenced_agent_ids) do
      {:ok, Enum.reverse(catalog.ordered)}
    end
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

  defp append_turn_agents(turn_rows, active) do
    Enum.reduce_while(turn_rows, {:ok, active}, fn
      %InteractionSchema{data: %Interaction.TurnStarted{} = turn}, {:ok, catalog} ->
        case historical_agent(turn, active.by_id) do
          {:ok, agent} -> append_agent(agent, catalog)
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  defp historical_agent(
         %Interaction.TurnStarted{
           agent_id: id,
           agent_name: nil,
           agent_display_name: nil,
           agent_description: nil,
           agent_color: nil
         },
         active_by_id
       ) do
    case Map.fetch(active_by_id, id) do
      {:ok, agent} -> {:ok, agent}
      :error -> {:error, {:unknown_legacy_agent, id}}
    end
  end

  defp historical_agent(%Interaction.TurnStarted{} = turn, _active_by_id) do
    attrs = %{
      id: turn.agent_id,
      name: turn.agent_name,
      display_name: turn.agent_display_name,
      description: turn.agent_description,
      color: turn.agent_color,
      system: nil,
      tools: []
    }

    try do
      {:ok, Agent.new!(attrs)}
    rescue
      ArgumentError -> {:error, {:invalid_agent_definition, turn.agent_id}}
    end
  end

  defp append_agents(agents, catalog) do
    Enum.reduce_while(agents, {:ok, catalog}, fn agent, {:ok, state} ->
      append_agent(agent, state)
    end)
  end

  defp append_agent(%Agent{id: id} = agent, catalog) do
    case Map.fetch(catalog.by_id, id) do
      :error ->
        {:cont,
         {:ok,
          %{
            ordered: [agent | catalog.ordered],
            by_id: Map.put(catalog.by_id, id, agent)
          }}}

      {:ok, existing} ->
        case same_definition?(existing, agent) do
          true -> {:cont, {:ok, catalog}}
          false -> {:halt, {:error, {:conflicting_agent_definition, id}}}
        end
    end
  end

  defp same_definition?(left, right) do
    {left.id, left.name, left.display_name, left.description, left.color} ==
      {right.id, right.name, right.display_name, right.description, right.color}
  end

  defp validate_referenced_agents(agents_by_id, agent_ids) do
    case Enum.find(agent_ids, &(not Map.has_key?(agents_by_id, &1))) do
      nil -> :ok
      agent_id -> {:error, {:unknown_agent, agent_id}}
    end
  end

  defp config do
    Application.fetch_env!(:frontman_server, __MODULE__)
  end
end
