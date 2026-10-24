# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Protocols.MCP.Schema do
  @moduledoc false

  @schema_dir Path.expand("../../../../../../libs/frontman-protocol/schemas/mcp", __DIR__)
  @discover_result_path Path.join(@schema_dir, "discoverResult.json")
  @tools_list_result_path Path.join(@schema_dir, "toolsListResult.json")
  @call_tool_result_path Path.join(@schema_dir, "callToolResult.json")

  @external_resource @discover_result_path
  @external_resource @tools_list_result_path
  @external_resource @call_tool_result_path

  @discover_result @discover_result_path |> File.read!() |> Jason.decode!() |> JSV.build!()
  @tools_list_result @tools_list_result_path |> File.read!() |> Jason.decode!() |> JSV.build!()
  @call_tool_result @call_tool_result_path |> File.read!() |> Jason.decode!() |> JSV.build!()

  @state_only_input_required JSV.build!(%{
                               "type" => "object",
                               "properties" => %{
                                 "resultType" => %{"const" => "input_required"},
                                 "requestState" => %{"type" => "string"},
                                 "_meta" => %{"type" => "object"}
                               },
                               "required" => ["resultType", "requestState"]
                             })

  def validate_discover_result(result), do: validate(result, @discover_result)

  def validate_tools_list_result(result) do
    with :ok <- validate(result, @tools_list_result),
         %{"tools" => tools} <- result,
         schemas =
           Enum.flat_map(tools, fn tool ->
             tool |> Map.take(["inputSchema", "outputSchema"]) |> Map.values()
           end),
         true <- Enum.all?(schemas, &(schema_nodes_remaining(&1, 64, 10_000) != :error)),
         true <-
           Enum.all?(
             schemas,
             &match?({:ok, _schema}, JSV.build(&1, atoms: false, warnings: :silent))
           ) do
      :ok
    else
      _error -> :error
    end
  end

  def validate_call_tool_result(%{"resultType" => "input_required"} = result)
      when not is_map_key(result, "inputRequests"),
      do: validate(result, @state_only_input_required)

  def validate_call_tool_result(result), do: validate(result, @call_tool_result)

  def validate_call_tool_result(%{"resultType" => "input_required"} = result, _output_schema)
      when not is_map_key(result, "inputRequests"),
      do: validate_call_tool_result(result)

  def validate_call_tool_result(%{"isError" => true} = result, output_schema)
      when is_map(output_schema) and not is_map_key(result, "structuredContent"),
      do: validate_call_tool_result(result)

  def validate_call_tool_result(result, output_schema) when is_map(output_schema) do
    with :ok <- validate_call_tool_result(result),
         {:ok, structured_content} <- Map.fetch(result, "structuredContent"),
         remaining when is_integer(remaining) <- schema_nodes_remaining(output_schema, 64, 10_000),
         {:ok, schema} <- JSV.build(output_schema, atoms: false, warnings: :silent),
         {:ok, _validated_data} <- JSV.validate(structured_content, schema, cast: false) do
      :ok
    else
      _error -> :error
    end
  end

  def validate_call_tool_result(result, nil), do: validate_call_tool_result(result)

  defp schema_nodes_remaining(_value, _depth, 0), do: :error

  defp schema_nodes_remaining(scalar, _depth, nodes) when not (is_map(scalar) or is_list(scalar)),
    do: nodes - 1

  defp schema_nodes_remaining(_container, depth, _nodes) when depth < 0, do: :error

  defp schema_nodes_remaining(value, depth, nodes) when is_map(value) do
    Enum.reduce_while(value, nodes - 1, fn {_key, child}, remaining ->
      schema_child_budget(child, depth - 1, remaining)
    end)
  end

  defp schema_nodes_remaining(value, depth, nodes) when is_list(value) do
    Enum.reduce_while(value, nodes - 1, fn child, remaining ->
      schema_child_budget(child, depth - 1, remaining)
    end)
  end

  defp schema_child_budget(child, depth, nodes) do
    case schema_nodes_remaining(child, depth, nodes) do
      :error -> {:halt, :error}
      remaining -> {:cont, remaining}
    end
  end

  defp validate(data, schema) do
    case JSV.validate(data, schema) do
      {:ok, _validated_data} -> :ok
      {:error, _error} -> :error
    end
  end
end
