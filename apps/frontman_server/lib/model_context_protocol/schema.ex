# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule ModelContextProtocol.Schema do
  @moduledoc false

  @discover_result_path Path.expand(
                          "../../../../libs/frontman-protocol/schemas/mcp/discoverResult.json",
                          __DIR__
                        )
  @tools_list_result_path Path.expand(
                            "../../../../libs/frontman-protocol/schemas/mcp/toolsListResult.json",
                            __DIR__
                          )

  @external_resource @discover_result_path
  @external_resource @tools_list_result_path

  @discover_result @discover_result_path |> File.read!() |> Jason.decode!() |> JSV.build!()
  @tools_list_result @tools_list_result_path |> File.read!() |> Jason.decode!() |> JSV.build!()

  def validate_discover_result(result), do: validate(result, @discover_result)
  def validate_tools_list_result(result), do: validate(result, @tools_list_result)

  defp validate(data, schema) do
    case JSV.validate(data, schema) do
      {:ok, _validated_data} -> :ok
      {:error, _error} -> :error
    end
  end
end
