# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.Daytona.Toolbox.Git do
  @moduledoc false

  alias FrontmanServer.PlayGithub.Daytona.Client

  def clone(%Client{} = client, sandbox_id, request, opts \\ [])
      when is_binary(sandbox_id) and is_map(request) and is_list(opts) do
    timeout_seconds = Keyword.get(opts, :timeout_seconds, 300)

    client
    |> Client.toolbox_request(sandbox_id)
    |> Req.post(
      url: "/git/clone",
      json: request,
      receive_timeout: timeout_seconds * 1_000 + 5_000
    )
  end
end
