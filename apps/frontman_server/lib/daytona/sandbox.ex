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
                                # Required
                                "dockerfileContent" => Zoi.string(),

                                # Optional
                                "contextHashes" => Zoi.array(Zoi.string()) |> Zoi.optional()
                              },
                              coerce: true
                            )

  @create_sandbox_schema Zoi.map(
                           %{
                             # Optional
                             "autoArchiveInterval" => Zoi.integer() |> Zoi.optional(),
                             "autoDeleteInterval" => Zoi.integer() |> Zoi.optional(),
                             "autoStopInterval" => Zoi.integer() |> Zoi.optional(),
                             "buildInfo" => @create_build_info_schema |> Zoi.optional(),
                             "cpu" => Zoi.integer() |> Zoi.optional(),
                             "disk" => Zoi.integer() |> Zoi.optional(),
                             "env" => Zoi.map(Zoi.any(), Zoi.any()) |> Zoi.optional(),
                             "gpu" => Zoi.integer() |> Zoi.optional(),
                             "labels" => Zoi.map(Zoi.any(), Zoi.any()) |> Zoi.optional(),
                             "linkedSandbox" => Zoi.string() |> Zoi.optional(),
                             "memory" => Zoi.integer() |> Zoi.optional(),
                             "name" => Zoi.string() |> Zoi.optional(),
                             "networkAllowList" => Zoi.string() |> Zoi.optional(),
                             "networkBlockAll" => Zoi.boolean() |> Zoi.optional(),
                             "public" => Zoi.boolean() |> Zoi.optional(),
                             "snapshot" => Zoi.string() |> Zoi.optional(),
                             "target" => Zoi.string() |> Zoi.optional(),
                             "user" => Zoi.string() |> Zoi.optional(),
                             "volumes" =>
                               Zoi.array(Zoi.map(Zoi.any(), Zoi.any())) |> Zoi.optional()
                           },
                           coerce: true
                         )

  def create(%Daytona{} = daytona, sandbox) when is_map(sandbox) do
    # API reference: https://www.daytona.io/docs/en/tools/api#daytona/tag/sandbox/POST/sandbox
    daytona
    |> Daytona.app_request()
    |> Req.post(url: "/sandbox", json: Zoi.parse!(@create_sandbox_schema, sandbox))
    |> create_response()
  end

  def get(%Daytona{} = daytona, sandbox_id) when is_binary(sandbox_id) do
    # API reference: https://www.daytona.io/docs/en/tools/api#daytona/tag/sandbox/GET/sandbox/{sandboxIdOrName}
    daytona
    |> Daytona.app_request()
    |> Req.get(url: "/sandbox/:sandbox_id", path_params: [sandbox_id: sandbox_id])
    |> get_response()
  end

  def start(%Daytona{} = daytona, sandbox_id) when is_binary(sandbox_id) do
    # API reference: https://www.daytona.io/docs/en/tools/api#daytona/tag/sandbox/POST/sandbox/{sandboxIdOrName}/start
    daytona
    |> Daytona.app_request()
    |> Req.post(url: "/sandbox/:sandbox_id/start", path_params: [sandbox_id: sandbox_id])
    |> start_response()
  end

  def get_preview_link(%Daytona{} = daytona, sandbox_id, port)
      when is_binary(sandbox_id) and is_integer(port) do
    # API reference: https://www.daytona.io/docs/en/tools/api#daytona/tag/sandbox/GET/sandbox/{sandboxIdOrName}/ports/{port}/preview-url
    daytona
    |> Daytona.app_request()
    |> Req.get(
      url: "/sandbox/:sandbox_id/ports/:port/preview-url",
      path_params: [sandbox_id: sandbox_id, port: port]
    )
    |> preview_link_response()
  end

  defp create_response({:ok, %Req.Response{status: status, body: %{"id" => sandbox_id}}})
       when status in 200..299 and is_binary(sandbox_id) do
    {:ok, %{id: sandbox_id}}
  end

  defp create_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:error, {:malformed_daytona_create_response, body}}
  end

  defp create_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:daytona_create_failed, status, body}}
  end

  defp create_response({:error, reason}), do: {:error, reason}

  defp get_response({:ok, %Req.Response{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp get_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:daytona_get_failed, status, body}}
  end

  defp get_response({:error, reason}), do: {:error, reason}

  defp start_response({:ok, %Req.Response{status: status, body: %{"state" => "started"}}})
       when status in 200..299 do
    :started
  end

  defp start_response({:ok, %Req.Response{status: status}}) when status in 200..299 do
    :ok
  end

  defp start_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:daytona_start_failed, status, body}}
  end

  defp start_response({:error, reason}), do: {:error, reason}

  defp preview_link_response(
         {:ok, %Req.Response{status: status, body: %{"url" => url, "token" => token}}}
       )
       when status in 200..299 and is_binary(url) and is_binary(token) do
    {:ok, %{url: url, preview_token: token}}
  end

  defp preview_link_response({:ok, %Req.Response{status: status, body: %{"url" => url}}})
       when status in 200..299 and is_binary(url) do
    {:ok, %{url: url, preview_token: nil}}
  end

  defp preview_link_response({:ok, %Req.Response{status: 404}}) do
    {:error, :daytona_sandbox_not_found}
  end

  defp preview_link_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:error, {:malformed_daytona_preview_response, body}}
  end

  defp preview_link_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:daytona_preview_lookup_failed, status, body}}
  end

  defp preview_link_response({:error, reason}), do: {:error, reason}
end
