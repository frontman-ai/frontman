# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Agents.Agent do
  @moduledoc """
  Backend-owned product agent definition.
  """

  @enforce_keys [:id, :name, :display_name, :description, :color, :system]
  defstruct [
    :id,
    :name,
    :display_name,
    :description,
    :color,
    :system,
    tools: :all,
    source: :static
  ]

  @hex_color ~r/\A#[0-9A-Fa-f]{6}\z/

  def new!(attrs) do
    agent = struct!(__MODULE__, attrs)

    case agent.color do
      color when is_binary(color) ->
        case Regex.match?(@hex_color, color) do
          true -> agent
          false -> raise_invalid_color!(agent)
        end

      _invalid ->
        raise_invalid_color!(agent)
    end
  end

  defp raise_invalid_color!(agent) do
    raise ArgumentError,
          "agent #{inspect(agent.name)} color must use #RRGGBB format, got: #{inspect(agent.color)}"
  end
end
