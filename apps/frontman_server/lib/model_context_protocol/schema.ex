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

  defp validate(data, schema) do
    case JSV.validate(data, schema) do
      {:ok, _validated_data} -> :ok
      {:error, _error} -> :error
    end
  end
end
