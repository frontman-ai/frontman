# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.Daytona.Sandbox.CreateBuildInfo do
  @moduledoc false

  @schema Zoi.struct(__MODULE__, %{
            dockerfile_content: Zoi.string(),
            context_hashes: Zoi.array(Zoi.string()) |> Zoi.optional()
          })

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
end

defimpl Jason.Encoder, for: FrontmanServer.PlayGithub.Daytona.Sandbox.CreateBuildInfo do
  def encode(build_info, opts) do
    %{
      "dockerfileContent" => build_info.dockerfile_content,
      "contextHashes" => build_info.context_hashes
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> Jason.Encode.map(opts)
  end
end
