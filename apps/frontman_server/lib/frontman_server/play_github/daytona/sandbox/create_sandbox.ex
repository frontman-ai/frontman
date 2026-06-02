# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.Daytona.Sandbox.CreateSandbox do
  @moduledoc false

  alias FrontmanServer.PlayGithub.Daytona.Sandbox.CreateBuildInfo

  @schema Zoi.struct(__MODULE__, %{
            name: Zoi.string() |> Zoi.optional(),
            snapshot: Zoi.string() |> Zoi.optional(),
            user: Zoi.string() |> Zoi.optional(),
            env: Zoi.map(Zoi.any(), Zoi.any()) |> Zoi.optional(),
            labels: Zoi.map(Zoi.any(), Zoi.any()) |> Zoi.optional(),
            public: Zoi.boolean() |> Zoi.optional(),
            network_block_all: Zoi.boolean() |> Zoi.optional(),
            network_allow_list: Zoi.string() |> Zoi.optional(),
            target: Zoi.string() |> Zoi.optional(),
            cpu: Zoi.integer() |> Zoi.optional(),
            gpu: Zoi.integer() |> Zoi.optional(),
            memory: Zoi.integer() |> Zoi.optional(),
            disk: Zoi.integer() |> Zoi.optional(),
            auto_stop_interval: Zoi.integer() |> Zoi.optional(),
            auto_archive_interval: Zoi.integer() |> Zoi.optional(),
            auto_delete_interval: Zoi.integer() |> Zoi.optional(),
            volumes: Zoi.array(Zoi.map(Zoi.any(), Zoi.any())) |> Zoi.optional(),
            build_info: Zoi.struct(CreateBuildInfo) |> Zoi.optional(),
            linked_sandbox: Zoi.string() |> Zoi.optional()
          })

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
end

defimpl Jason.Encoder, for: FrontmanServer.PlayGithub.Daytona.Sandbox.CreateSandbox do
  def encode(sandbox, opts) do
    %{
      "name" => sandbox.name,
      "snapshot" => sandbox.snapshot,
      "user" => sandbox.user,
      "env" => sandbox.env,
      "labels" => sandbox.labels,
      "public" => sandbox.public,
      "networkBlockAll" => sandbox.network_block_all,
      "networkAllowList" => sandbox.network_allow_list,
      "target" => sandbox.target,
      "cpu" => sandbox.cpu,
      "gpu" => sandbox.gpu,
      "memory" => sandbox.memory,
      "disk" => sandbox.disk,
      "autoStopInterval" => sandbox.auto_stop_interval,
      "autoArchiveInterval" => sandbox.auto_archive_interval,
      "autoDeleteInterval" => sandbox.auto_delete_interval,
      "volumes" => sandbox.volumes,
      "buildInfo" => sandbox.build_info,
      "linkedSandbox" => sandbox.linked_sandbox
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Jason.Encode.map(opts)
  end
end
