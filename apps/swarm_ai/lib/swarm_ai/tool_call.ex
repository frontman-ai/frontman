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

  @doc "Returns true if the tool call has a result."
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{result: nil}), do: false
  def completed?(%__MODULE__{result: %ToolResult{}}), do: true

  @doc "Adds a result to the tool call."
  @spec with_result(t(), ToolResult.t()) :: t()
  def with_result(%__MODULE__{} = tc, %ToolResult{} = result) do
    %{tc | result: result}
  end

  @doc """
  Extracts the tool name from a tool call or tool-call-shaped map.

  Handles `SwarmAi.ToolCall` structs and various map shapes found in
  telemetry metadata (`:name`, `:tool_name`, and OpenAI wire format).

  Returns `"unknown"` for unrecognised shapes.

  ## Examples

      iex> tc = %SwarmAi.ToolCall{id: "1", name: "get_weather", arguments: "{}"}
      iex> SwarmAi.ToolCall.extract_name(tc)
      "get_weather"
  """
  @spec extract_name(t() | map()) :: String.t()
  def extract_name(%__MODULE__{name: name}), do: name
  def extract_name(%{tool_name: name}), do: name
  def extract_name(%{name: name}), do: name
  def extract_name(%{"function" => %{"name" => name}}), do: name
  def extract_name(_), do: "unknown"

  @doc """
  Extracts the arguments JSON string from a tool call or tool-call-shaped map.

  Always returns a JSON string. For structs/maps with pre-encoded arguments
  the string is returned directly; for maps with decoded arguments it
  re-encodes via `Jason.encode!/1`.

  Returns `"{}"` for unrecognised shapes.

  ## Examples

      iex> tc = %SwarmAi.ToolCall{id: "1", name: "get_weather", arguments: ~s({"location":"NYC"})}
      iex> SwarmAi.ToolCall.extract_args_json(tc)
      ~s({"location":"NYC"})
  """
  @spec extract_args_json(t() | map()) :: String.t()
  def extract_args_json(%__MODULE__{arguments: args}), do: args
  def extract_args_json(%{arguments: args}) when is_binary(args), do: args
  def extract_args_json(%{arguments: args}), do: Jason.encode!(args)
  def extract_args_json(%{"function" => %{"arguments" => args}}), do: args
  def extract_args_json(_), do: "{}"

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
