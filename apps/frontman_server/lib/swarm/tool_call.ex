defmodule Swarm.ToolCall do
  @moduledoc """
  Represents a tool call from the LLM and its result.

  Simple, flat structure. Adapters translate from provider formats.
  The result field is populated after the tool has been executed.
  """
  use TypedStruct

  alias Swarm.ToolResult

  typedstruct do
    field :id, String.t(), enforce: true
    field :name, String.t(), enforce: true
    field :arguments, String.t(), enforce: true
    field :result, ToolResult.t()
  end

  @doc "Returns true if the tool call has a result."
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{result: result}), do: result != nil

  @doc "Adds a result to the tool call."
  @spec with_result(t(), ToolResult.t()) :: t()
  def with_result(%__MODULE__{} = tc, %ToolResult{} = result) do
    %{tc | result: result}
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
