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

  def list_sites(%Scope{} = scope) do
    scope
    |> Scope.user_id()
    |> Connection.sites_for_user()
    |> Repo.all()
    |> Enum.map(fn site -> %{id: site.id, label: URI.parse(site.catalog_url).host} end)
  end

  def catalog(%Scope{} = scope, id, timeout) when timeout > 0 do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Connection{} = connection <-
           scope |> Scope.user_id() |> Connection.owned() |> Repo.get(id) do
      request(
        connection.catalog_url,
        connection.username,
        connection.password,
        :get,
        nil,
        timeout
      )
    else
      _ -> {:error, :connection_failed}
    end
  end

  def call(%Scope{} = scope, id, name, arguments) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Connection{} = connection <-
           scope |> Scope.user_id() |> Connection.owned() |> Repo.get(id) do
      request(connection.call_url, connection.username, connection.password, :post, %{
        name: name,
        arguments: arguments
      })
    else
      _ -> {:error, :connection_failed}
    end
  end

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

  defp origin(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, userinfo: nil, fragment: nil, port: port}
      when is_binary(host) and byte_size(host) > 0 ->
        {:ok, {String.downcase(host), port}}

      _ ->
        {:error, :invalid_url}
    end
  end

  defp request(url, username, password, method, body, timeout \\ 15_000) do
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
            plugins:
              if(Application.get_env(:frontman_server, :env) == :dev, do: [], else: [PublicURL]),
            redirect: false,
            retry: false,
            receive_timeout: min(timeout, 10_000),
            decode_body: false,
            into: into
          )
        rescue
          _ -> {:error, :request_failed}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %{status: 200, body: response}}} -> Jason.decode(response)
      _ -> {:error, :request_failed}
    end
  end
end
