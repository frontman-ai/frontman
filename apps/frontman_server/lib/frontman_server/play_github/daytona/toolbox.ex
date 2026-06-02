# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.Daytona.Toolbox do
  @moduledoc false

  alias FrontmanServer.PlayGithub.Daytona.Client

  def execute_command(%Client{} = client, sandbox_id, command)
      when is_binary(sandbox_id) and is_binary(command) do
    execute_command(client, sandbox_id, command, [])
  end

  def execute_command(sandbox_id, command, opts)
      when is_binary(sandbox_id) and is_binary(command) and is_list(opts) do
    with {:ok, client} <- Client.new() do
      execute_command(client, sandbox_id, command, opts)
    end
  end

  def execute_command(%Client{} = client, sandbox_id, command, opts)
      when is_binary(sandbox_id) and is_binary(command) and is_list(opts) do
    timeout_seconds = Keyword.get(opts, :timeout_seconds, 300)

    client
    |> Client.toolbox_request(sandbox_id)
    |> Req.post(
      url: "/process/execute",
      json: %{
        command: command,
        cwd: Keyword.get(opts, :cwd, "workspace"),
        timeout: timeout_seconds
      },
      receive_timeout: timeout_seconds * 1_000 + 5_000
    )
  end

  def execute_command(sandbox_id, command) when is_binary(sandbox_id) and is_binary(command) do
    execute_command(sandbox_id, command, [])
  end
end
