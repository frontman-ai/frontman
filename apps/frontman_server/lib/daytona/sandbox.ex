# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule Daytona.Sandbox do
  @moduledoc false

  alias Daytona

  @create_build_info_schema Zoi.map(
                              %{
                                "dockerfileContent" => Zoi.string(),
                                "contextHashes" => Zoi.array(Zoi.string()) |> Zoi.optional()
                              },
                              coerce: true
                            )

  @create_sandbox_schema Zoi.map(
                           %{
                             "name" => Zoi.string() |> Zoi.optional(),
                             "snapshot" => Zoi.string() |> Zoi.optional(),
                             "user" => Zoi.string() |> Zoi.optional(),
                             "env" => Zoi.map(Zoi.any(), Zoi.any()) |> Zoi.optional(),
                             "labels" => Zoi.map(Zoi.any(), Zoi.any()) |> Zoi.optional(),
                             "public" => Zoi.boolean() |> Zoi.optional(),
                             "networkBlockAll" => Zoi.boolean() |> Zoi.optional(),
                             "networkAllowList" => Zoi.string() |> Zoi.optional(),
                             "target" => Zoi.string() |> Zoi.optional(),
                             "cpu" => Zoi.integer() |> Zoi.optional(),
                             "gpu" => Zoi.integer() |> Zoi.optional(),
                             "memory" => Zoi.integer() |> Zoi.optional(),
                             "disk" => Zoi.integer() |> Zoi.optional(),
                             "autoStopInterval" => Zoi.integer() |> Zoi.optional(),
                             "autoArchiveInterval" => Zoi.integer() |> Zoi.optional(),
                             "autoDeleteInterval" => Zoi.integer() |> Zoi.optional(),
                             "volumes" =>
                               Zoi.array(Zoi.map(Zoi.any(), Zoi.any())) |> Zoi.optional(),
                             "buildInfo" => @create_build_info_schema |> Zoi.optional(),
                             "linkedSandbox" => Zoi.string() |> Zoi.optional()
                           },
                           coerce: true
                         )

  def create(%Daytona{} = daytona, sandbox) when is_map(sandbox) do
    daytona
    |> Daytona.app_request()
    |> Req.post(url: "/sandbox", json: Zoi.parse!(@create_sandbox_schema, sandbox))
  end

  def get(%Daytona{} = daytona, sandbox_id) when is_binary(sandbox_id) do
    daytona
    |> Daytona.app_request()
    |> Req.get(url: "/sandbox/:sandbox_id", path_params: [sandbox_id: sandbox_id])
  end

  def start(%Daytona{} = daytona, sandbox_id) when is_binary(sandbox_id) do
    daytona
    |> Daytona.app_request()
    |> Req.post(url: "/sandbox/:sandbox_id/start", path_params: [sandbox_id: sandbox_id])
  end

  def get_preview_link(%Daytona{} = daytona, sandbox_id, port)
      when is_binary(sandbox_id) and is_integer(port) do
    daytona
    |> Daytona.app_request()
    |> Req.get(
      url: "/sandbox/:sandbox_id/ports/:port/preview-url",
      path_params: [sandbox_id: sandbox_id, port: port]
    )
  end
end
