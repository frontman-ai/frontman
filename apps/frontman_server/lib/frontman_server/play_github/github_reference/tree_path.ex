# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.GithubReference.TreePath do
  @moduledoc """
  GitHub tree path with a string-only ref split.
  """

  @schema Zoi.struct(__MODULE__, %{
            ref: Zoi.string(),
            path_segments: Zoi.array(Zoi.string()) |> Zoi.default([]) |> Zoi.optional()
          })

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec repo_path(t()) :: String.t() | nil
  def repo_path(%__MODULE__{path_segments: []}), do: nil
  def repo_path(%__MODULE__{path_segments: path_segments}), do: Enum.join(path_segments, "/")
end
