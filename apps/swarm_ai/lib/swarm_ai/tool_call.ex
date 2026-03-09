defmodule SwarmAi.ToolCall do
  @moduledoc """
  Represents a tool call from the LLM and its result.

  Simple, flat structure. Adapters translate from provider formats.
  The result field is populated after the tool has been executed.
  """
  use TypedStruct

  alias SwarmAi.ToolResult

  typedstruct do
    field(:id, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)
    field(:arguments, String.t(), enforce: true)
    field(:result, ToolResult.t())
  end

  @doc "Returns true if the tool call has a non-suspended result."
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{result: nil}), do: false
  def completed?(%__MODULE__{result: %ToolResult{suspended: true}}), do: false
  def completed?(%__MODULE__{result: %ToolResult{}}), do: true

  @doc "Returns true if the tool call has a suspended result."
  @spec suspended?(t()) :: boolean()
  def suspended?(%__MODULE__{result: %ToolResult{suspended: true}}), do: true
  def suspended?(%__MODULE__{result: _}), do: false

  @doc "Adds a result to the tool call."
  @spec with_result(t(), ToolResult.t()) :: t()
  def with_result(%__MODULE__{} = tc, %ToolResult{} = result) do
    %{tc | result: result}
  end

  @doc """
  Parse arguments JSON string to a map.

  ## Example

      iex> tc = %SwarmAi.ToolCall{id: "1", name: "get_weather", arguments: ~s({"location":"NYC"})}
      iex> SwarmAi.ToolCall.parse_arguments(tc)
      {:ok, %{"location" => "NYC"}}
  """
  @spec parse_arguments(t()) :: {:ok, map()} | {:error, Jason.DecodeError.t()}
  def parse_arguments(%__MODULE__{arguments: json}) do
    Jason.decode(json)
  end

  @doc """
  Strips null values from arguments JSON.

  OpenAI strict mode makes optional fields nullable (`anyOf: [type, null]`),
  so the model sends `null` instead of omitting. Tools expect missing keys,
  not null values.

  ## Example

      iex> tc = %SwarmAi.ToolCall{id: "1", name: "click", arguments: ~s({"selector":"#btn","timeout":null})}
      iex> SwarmAi.ToolCall.strip_null_arguments(tc).arguments
      ~s({"selector":"#btn"})
  """
  @spec strip_null_arguments(t()) :: t()
  def strip_null_arguments(%__MODULE__{arguments: arguments} = tc) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, args} when is_map(args) ->
        %{tc | arguments: Jason.encode!(SwarmAi.SchemaTransformer.strip_nulls(args))}

      _ ->
        tc
    end
  end

  def strip_null_arguments(tc), do: tc
end
