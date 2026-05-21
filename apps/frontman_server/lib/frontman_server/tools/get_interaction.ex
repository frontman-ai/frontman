# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.GetInteraction do
  @moduledoc """
  Retrieves a task interaction by interaction ID or tool call ID.
  """

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tasks.Interaction.ToolResult
  alias FrontmanServer.Tools.Backend
  alias FrontmanServer.Tools.Backend.Context

  @impl true
  @spec name() :: String.t()
  def name, do: "get_interaction"

  @impl true
  @spec description() :: String.t()
  def description do
    """
    Retrieve a previous interaction by ID.

    Use this when a prior tool result says its data was omitted. Pass the exact
    ID from that placeholder to retrieve the full stored interaction.
    """
  end

  @impl true
  @spec parameter_schema() :: map()
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{
          "type" => "string",
          "description" => "The interaction ID or tool call ID to retrieve."
        }
      },
      "required" => ["id"]
    }
  end

  @impl true
  def timeout_ms, do: 30_000

  @impl true
  def on_timeout, do: :error

  @impl true
  @spec execute(map(), Context.t()) :: Backend.result()
  def execute(args, %Context{task: %{interactions: interactions}}) do
    case Map.get(args, "id") || Map.get(args, :id) do
      id when is_binary(id) ->
        find_interaction(interactions, id)

      _ ->
        {:error, "id must be a string"}
    end
  end

  defp find_interaction(interactions, id) do
    case Enum.find(interactions, &matches_id?(&1, id)) do
      nil -> {:error, "Interaction not found: #{id}"}
      interaction -> {:ok, interaction |> Jason.encode!() |> Jason.decode!()}
    end
  end

  defp matches_id?(interaction, id),
    do: Map.get(interaction, :id) == id or tool_call_id?(interaction, id)

  defp tool_call_id?(%ToolResult{tool_call_id: tool_call_id}, id), do: tool_call_id == id
  defp tool_call_id?(_interaction, _id), do: false
end
