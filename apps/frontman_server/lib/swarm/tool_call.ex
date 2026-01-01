defmodule Swarm.ToolCall do
  @moduledoc """
  Represents a tool call from the LLM.

  Simple, flat structure. Adapters translate from provider formats.
  """
  use TypedStruct

  typedstruct enforce: true do
    field :id, String.t()
    field :name, String.t()
    field :arguments, String.t()
  end

  @doc """
  Parse arguments JSON string to a map.

  ## Example

      iex> tc = %Swarm.ToolCall{id: "1", name: "get_weather", arguments: ~s({"location":"NYC"})}
      iex> Swarm.ToolCall.parse_arguments(tc)
      {:ok, %{"location" => "NYC"}}
  """
  @spec parse_arguments(t()) :: {:ok, map()} | {:error, Jason.DecodeError.t()}
  def parse_arguments(%__MODULE__{arguments: json}) do
    Jason.decode(json)
  end
end
