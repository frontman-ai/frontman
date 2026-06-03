# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule Daytona.Toolbox.Git do
  @moduledoc false

  alias Daytona.Toolbox

  @clone_request_schema Zoi.map(
                          %{
                            "branch" => Zoi.string() |> Zoi.optional() |> Zoi.default(""),
                            "commit_id" => Zoi.string() |> Zoi.optional() |> Zoi.default(""),
                            "password" => Zoi.string() |> Zoi.optional() |> Zoi.default(""),
                            "path" => Zoi.string() |> Zoi.gte(1),
                            "url" => Zoi.string() |> Zoi.gte(1),
                            "username" => Zoi.string() |> Zoi.optional() |> Zoi.default("")
                          },
                          coerce: true
                        )

  @type clone_request :: unquote(Zoi.type_spec(@clone_request_schema))

  @spec clone(Toolbox.t(), String.t(), clone_request(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def clone(%Toolbox{} = toolbox, sandbox_id, request, opts \\ [])
      when is_binary(sandbox_id) and is_map(request) and is_list(opts) do
    timeout_seconds = Keyword.get(opts, :timeout_seconds, 300)

    toolbox
    |> Toolbox.request(sandbox_id)
    |> Req.post(
      url: "/git/clone",
      json: Zoi.parse!(@clone_request_schema, request),
      receive_timeout: timeout_seconds * 1_000 + 5_000
    )
  end
end
