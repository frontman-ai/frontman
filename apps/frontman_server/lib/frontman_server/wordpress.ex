# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.WordPress do
  @moduledoc false

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.{PublicURL, Repo}
  alias FrontmanServer.WordPress.Connection

  def connect(%Scope{} = scope, %{
        "catalog_url" => catalog_url,
        "call_url" => call_url,
        "username" => username,
        "password" => password
      })
      when is_binary(catalog_url) and is_binary(call_url) and is_binary(username) and
             is_binary(password) and byte_size(catalog_url) <= 2048 and
             byte_size(call_url) <= 2048 and byte_size(username) in 1..255 and
             byte_size(password) in 1..256 do
    with {:ok, origin} <- origin(catalog_url),
         {:ok, ^origin} <- origin(call_url),
         {:ok, %{"tools" => tools}} when is_list(tools) <-
           request(catalog_url, username, password, :get, nil),
         true <- Enum.any?(tools, &match?(%{"name" => "wp_read_post"}, &1)),
         {:ok, connection} <-
           %Connection{user_id: Scope.user_id(scope)}
           |> Connection.changeset(%{
             catalog_url: catalog_url,
             call_url: call_url,
             username: username,
             password: password
           })
           |> Repo.insert() do
      {:ok, connection.id}
    else
      _ -> {:error, :connection_failed}
    end
  end

  def connect(%Scope{}, _params), do: {:error, :connection_failed}

  def read_post(%Scope{} = scope, id, post_id)
      when is_binary(id) and is_integer(post_id) and post_id > 0 do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Connection{} = connection <- Repo.one(Connection.for_owner(id, Scope.user_id(scope))),
         {:ok, body} <-
           request(connection.call_url, connection.username, connection.password, :post, %{
             name: "wp_read_post",
             arguments: %{id: post_id}
           }) do
      {:ok, body}
    else
      _ -> {:error, :request_failed}
    end
  end

  def read_post(%Scope{}, _id, _post_id), do: {:error, :request_failed}

  defp origin(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, userinfo: nil, fragment: nil, port: port}
      when is_binary(host) and byte_size(host) > 0 ->
        {:ok, {String.downcase(host), port}}

      _ ->
        {:error, :invalid_url}
    end
  end

  defp request(url, username, password, method, body) do
    limit = 1_000_000

    into = fn {:data, data}, {req, resp} ->
      case byte_size(resp.body) + byte_size(data) <= limit do
        true -> {:cont, {req, %{resp | body: resp.body <> data}}}
        false -> {:halt, {req, %{resp | status: 0, body: ""}}}
      end
    end

    task =
      Task.async(fn ->
        try do
          Req.request(
            method: method,
            url: url,
            auth: {:basic, "#{username}:#{password}"},
            json: body,
            plugins: [PublicURL],
            redirect: false,
            retry: false,
            receive_timeout: 10_000,
            decode_body: false,
            into: into
          )
        rescue
          _ -> {:error, :request_failed}
        end
      end)

    case Task.yield(task, 15_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %{status: 200, body: response}}} -> Jason.decode(response)
      _ -> {:error, :request_failed}
    end
  end
end
