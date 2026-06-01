# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.GithubReference.TreePath do
  @moduledoc """
  GitHub tree path with a string-only ref split.
  """

  use TypedStruct

  typedstruct enforce: true do
    field(:ref, String.t())
    field(:path_segments, [String.t()], default: [])
  end

  @spec repo_path(t()) :: String.t() | nil
  def repo_path(%__MODULE__{path_segments: []}), do: nil
  def repo_path(%__MODULE__{path_segments: path_segments}), do: Enum.join(path_segments, "/")
end
