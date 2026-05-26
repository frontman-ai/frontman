# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.GithubPath do
  @moduledoc """
  GitHub repository path parsed from a PlayGithub local URL.
  """

  use TypedStruct

  alias FrontmanServer.PlayGithub.{GithubIssuePath, GithubRepositoryPath, GithubTreePath}

  @type resource :: GithubRepositoryPath.t() | GithubTreePath.t() | GithubIssuePath.t()

  typedstruct enforce: true do
    field(:owner, String.t())
    field(:repo, String.t())
    field(:resource, resource())
    field(:raw_segments, [String.t()])
  end
end
