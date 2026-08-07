defmodule SwarmAi.ToolCall do
  use TypedStruct

  alias SwarmAi.ToolResult

  typedstruct do
    field(:id, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)
    field(:arguments, String.t(), enforce: true)
    field(:result, ToolResult.t())
  end

  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{result: nil}), do: false
  def completed?(%__MODULE__{result: %ToolResult{}}), do: true

  @spec with_result(t(), ToolResult.t()) :: t()
  def with_result(%__MODULE__{} = tc, %ToolResult{} = result) do
    %{tc | result: result}
  end

  @spec extract_name(t() | map()) :: String.t()
  def extract_name(%__MODULE__{name: name}), do: name
  def extract_name(%{tool_name: name}), do: name
  def extract_name(%{name: name}), do: name
  def extract_name(%{"function" => %{"name" => name}}), do: name
  def extract_name(_), do: "unknown"

  @spec extract_args_json(t() | map()) :: String.t()
  def extract_args_json(%__MODULE__{arguments: args}), do: args
  def extract_args_json(%{arguments: args}) when is_binary(args), do: args
  def extract_args_json(%{arguments: args}), do: Jason.encode!(args)
  def extract_args_json(%{"function" => %{"arguments" => args}}), do: args
  def extract_args_json(_), do: "{}"

  @spec parse_arguments(t()) :: {:ok, map()} | {:error, String.t()}
  def parse_arguments(%__MODULE__{arguments: arguments}) do
    case String.trim(arguments) do
      "" ->
        {:ok, %{}}

      arguments ->
        case Jason.decode(arguments) do
          {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
          {:ok, decoded} -> {:error, "expected JSON object, got #{inspect(decoded)}"}
          {:error, decode_error} -> {:error, Exception.message(decode_error)}
        end
    end
  end

  @spec strip_null_arguments(t()) :: t()
  def strip_null_arguments(%__MODULE__{} = tc) do
    case parse_arguments(tc) do
      {:ok, args} ->
        %{tc | arguments: Jason.encode!(SwarmAi.SchemaTransformer.strip_nulls(args))}

      {:error, _reason} ->
        tc
    end
  end
end
