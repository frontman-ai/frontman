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

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          display_name: String.t(),
          description: String.t(),
          color: String.t(),
          system: String.t() | nil,
          tools: :all | [String.t()],
          source: atom()
        }

  def new!(attrs) do
    agent = struct!(__MODULE__, attrs)

    with true <- non_empty_string?(agent.id),
         true <- non_empty_string?(agent.name),
         true <- non_empty_string?(agent.display_name),
         true <- non_empty_string?(agent.description),
         true <- valid_color?(agent.color) do
      agent
    else
      false -> raise ArgumentError, "invalid agent definition: #{inspect(agent)}"
    end
  end

  defp non_empty_string?(value) when is_binary(value), do: value != ""
  defp non_empty_string?(_value), do: false

  defp valid_color?(color) when is_binary(color), do: Regex.match?(@hex_color, color)
  defp valid_color?(_color), do: false
end
