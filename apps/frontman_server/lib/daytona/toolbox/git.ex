# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule Daytona.Toolbox.Git do
  @moduledoc false

  alias Daytona.Toolbox

  @default_clone_timeout_seconds 300

  @clone_request_schema Zoi.map(
                          %{
                            # Required
                            "path" => Zoi.string() |> Zoi.gte(1),
                            "url" => Zoi.string() |> Zoi.gte(1),

                            # Optional
                            "branch" => Zoi.string() |> Zoi.optional(),
                            "commit_id" => Zoi.string() |> Zoi.optional(),
                            "password" => Zoi.string() |> Zoi.optional(),
                            "username" => Zoi.string() |> Zoi.optional()
                          },
                          coerce: true
                        )

  def clone(%Toolbox{} = toolbox, sandbox_id, %{request: request} = params)
      when is_binary(sandbox_id) and is_map(request) do
    timeout_seconds = Map.get(params, :timeout_seconds, @default_clone_timeout_seconds)

    # API reference: https://www.daytona.io/docs/en/tools/api#daytona-toolbox/tag/git/POST/git/clone
    toolbox
    |> Toolbox.request(sandbox_id)
    |> Req.post(
      url: "/git/clone",
      json: Zoi.parse!(@clone_request_schema, request),
      # Keep Req slightly past the clone budget so Daytona can return its own timeout/error body.
      receive_timeout: timeout_seconds * 1_000 + 5_000
    )
    |> clone_response()
  end

  defp clone_response({:ok, %Req.Response{status: status}}) when status in 200..299 do
    :ok
  end

  defp clone_response(
         {:ok,
          %Req.Response{
            body: %{"code" => "CONFLICT", "message" => "conflict: repository already exists"}
          }}
       ) do
    {:error, :repository_already_exists}
  end

  defp clone_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:daytona_git_clone_failed, status, body}}
  end

  defp clone_response({:error, reason}), do: {:error, reason}
end
