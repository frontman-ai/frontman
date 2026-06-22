# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule Daytona.Toolbox.Process do
  @moduledoc false

  alias Daytona.Toolbox

  @execute_request_schema Zoi.map(
                            %{
                              # Required
                              "command" => Zoi.string() |> Zoi.gte(1),

                              # Optional
                              "cwd" => Zoi.string() |> Zoi.optional(),
                              "envs" =>
                                Zoi.map(Zoi.string(), Zoi.string())
                                |> Zoi.optional()
                                |> Zoi.default(%{}),
                              "timeout" => Zoi.integer() |> Zoi.optional() |> Zoi.default(10)
                            },
                            coerce: true
                          )

  def execute(%Toolbox{} = toolbox, sandbox_id, request, opts \\ [])
      when is_binary(sandbox_id) and is_map(request) and is_list(opts) do
    request = Zoi.parse!(@execute_request_schema, request)
    timeout_seconds = Keyword.get(opts, :timeout_seconds, request["timeout"])

    # API reference: https://www.daytona.io/docs/en/tools/api#daytona-toolbox/tag/process/POST/process/execute
    toolbox
    |> Toolbox.request(sandbox_id)
    |> Req.post(
      url: "/process/execute",
      json: request,
      receive_timeout: timeout_seconds * 1_000 + 5_000
    )
    |> execute_response()
  end

  defp execute_response(
         {:ok, %Req.Response{status: status, body: %{"exitCode" => exit_code} = body}}
       )
       when status in 200..299 and is_integer(exit_code) do
    {:ok, %{exit_code: exit_code, body: body}}
  end

  defp execute_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:error, {:malformed_daytona_process_execute_response, body}}
  end

  defp execute_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:daytona_process_execute_failed, status, body}}
  end

  defp execute_response({:error, reason}), do: {:error, reason}
end
