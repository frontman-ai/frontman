# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule ModelContextProtocol.Schema do
  @moduledoc false

  @schema_dir Path.expand("../../../../libs/frontman-protocol/schemas/mcp", __DIR__)
  @discover_result_path Path.join(@schema_dir, "discoverResult.json")
  @tools_list_result_path Path.join(@schema_dir, "toolsListResult.json")
  @call_tool_result_path Path.join(@schema_dir, "callToolResult.json")

  @external_resource @discover_result_path
  @external_resource @tools_list_result_path
  @external_resource @call_tool_result_path

  @discover_result @discover_result_path |> File.read!() |> Jason.decode!() |> JSV.build!()
  @tools_list_result @tools_list_result_path |> File.read!() |> Jason.decode!() |> JSV.build!()
  @call_tool_result @call_tool_result_path |> File.read!() |> Jason.decode!() |> JSV.build!()

  def validate_discover_result(result), do: validate(result, @discover_result)
  def validate_tools_list_result(result), do: validate(result, @tools_list_result)
  def validate_call_tool_result(result), do: validate(result, @call_tool_result)

  def validate_call_tool_result(%{"isError" => true} = result, output_schema)
      when is_map(output_schema) and not is_map_key(result, "structuredContent"),
      do: validate_call_tool_result(result)

  def validate_call_tool_result(result, output_schema) when is_map(output_schema) do
    with :ok <- validate_call_tool_result(result),
         {:ok, structured_content} <- Map.fetch(result, "structuredContent"),
         {:ok, schema} <- JSV.build(output_schema, atoms: false, warnings: :silent),
         {:ok, _validated_data} <- JSV.validate(structured_content, schema, cast: false) do
      :ok
    else
      _error -> :error
    end
  end

  def validate_call_tool_result(result, nil), do: validate_call_tool_result(result)

  defp validate(data, schema) do
    case JSV.validate(data, schema) do
      {:ok, _validated_data} -> :ok
      {:error, _error} -> :error
    end
  end
end
