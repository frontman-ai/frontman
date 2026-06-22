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
                              "command" => Zoi.string() |> Zoi.gte(1),
                              "cwd" => Zoi.string() |> Zoi.optional() |> Zoi.default(""),
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

    toolbox
    |> Toolbox.request(sandbox_id)
    |> Req.post(
      url: "/process/execute",
      json: request,
      receive_timeout: timeout_seconds * 1_000 + 5_000
    )
  end
end
