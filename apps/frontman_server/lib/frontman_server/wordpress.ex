# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.WordPress do
  @moduledoc false

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Protocols.MCP.Schema
  alias FrontmanServer.{PublicURL, Repo}
  alias FrontmanServer.WordPress.Connection

  def list_sites(%Scope{} = scope) do
    scope
    |> Scope.user_id()
    |> Connection.sites_for_user()
    |> Repo.all()
    |> Enum.map(fn site -> %{id: site.id, label: URI.parse(site.catalog_url).host} end)
  end

  def list_site_links(%Scope{} = scope) do
    scope
    |> Scope.user_id()
    |> Connection.sites_for_user()
    |> Repo.all()
    |> Enum.flat_map(fn site ->
      case frontman_url(site.catalog_url) do
        {:ok, url} -> [%{id: site.id, label: URI.parse(url).host, url: url}]
        :error -> []
      end
    end)
    |> Enum.uniq_by(& &1.url)
  end

  def catalog(%Scope{} = scope, site_id, timeout) when timeout > 0 do
    request_site(scope, site_id, :get, nil, timeout)
  end

  def discover_tools(%Scope{} = scope, site_ids) do
    started = System.monotonic_time(:millisecond)
    deadline = started + 6_000

    {status, result, validated} =
      scope
      |> stream_catalogs(site_ids, deadline)
      |> Enum.reduce_while({:ok, [], 0}, fn
        {:ok, {id, {:ok, catalog}}}, {:ok, entries, validated} ->
          case validated_tools(catalog, deadline) do
            {:ok, tools} ->
              {:cont, {:ok, Enum.map(tools, &{id, &1}) ++ entries, validated + 1}}

            {:error, reason} ->
              {:halt, {:error, reason, validated}}
          end

        {:exit, :timeout}, {:ok, _, validated} ->
          {:halt, {:error, :timeout, validated}}

        {:exit, _}, {:ok, _, validated} ->
          {:halt, {:error, :task_exit, validated}}

        _, {:ok, _, validated} ->
          category =
            if System.monotonic_time(:millisecond) >= deadline,
              do: :deadline_expired,
              else: :request_failed

          {:halt, {:error, category, validated}}
      end)

    outcome = if status == :ok, do: :ok, else: result
    discovery_event(outcome, started, validated, length(site_ids))
    {status, result}
  end

  @doc """
  Streams catalogs until an absolute monotonic deadline in milliseconds.

  Loads owned connections before starting cancellable HTTP workers. Cancellation
  must not interrupt a database checkout and disconnect its transaction.
  Each batch contains at most one connection per origin, so discovery cannot
  flood a shared WordPress server while independent origins remain concurrent.
  """
  def stream_catalogs(%Scope{} = scope, site_ids, deadline) do
    connections =
      scope
      |> Scope.user_id()
      |> Connection.owned_ids(site_ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    site_ids
    |> Enum.group_by(fn id ->
      case Map.fetch(connections, id) do
        {:ok, connection} -> origin(connection.catalog_url)
        :error -> {:missing, id}
      end
    end)
    |> Map.values()
    |> catalog_batches()
    |> Stream.flat_map(fn batch ->
      Task.async_stream(
        batch,
        &fetch_catalog(connections, &1, deadline),
        max_concurrency: 32,
        ordered: false,
        timeout: max(deadline - System.monotonic_time(:millisecond), 1),
        on_timeout: :kill_task
      )
    end)
  end

  def call(%Scope{} = scope, site_id, name, arguments) do
    request_site(scope, site_id, :post, %{name: name, arguments: arguments}, 15_000)
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

  def connected?(%Scope{} = scope, catalog_url) when is_binary(catalog_url) do
    scope |> Scope.user_id() |> Connection.owned_catalog(catalog_url) |> Repo.exists?()
  end

  defp validated_tools(%{"tools" => tools} = catalog, deadline) do
    defaults = %{"resultType" => "complete", "ttlMs" => 0, "cacheScope" => "private"}

    cond do
      Map.get(catalog, "resultType", "complete") != "complete" -> {:error, :incomplete}
      Map.get(catalog, "nextCursor") not in [nil, ""] -> {:error, :paginated}
      not Schema.bounded?(catalog) -> {:error, :bounds}
      System.monotonic_time(:millisecond) >= deadline -> {:error, :deadline_expired}
      Schema.validate_tools_list_envelope(Map.merge(defaults, catalog)) == :ok -> {:ok, tools}
      true -> {:error, :schema}
    end
  end

  defp validated_tools(_, _deadline), do: {:error, :schema}

  defp discovery_event(outcome, started, validated, total) do
    :telemetry.execute(
      [:frontman_server, :wordpress, :discovery, :stop],
      %{
        duration_ms: max(System.monotonic_time(:millisecond) - started, 0),
        validated: validated,
        total: total
      },
      %{outcome: outcome}
    )
  end

  defp frontman_url(catalog_url) do
    with {:ok, %URI{scheme: "https", userinfo: nil, fragment: nil, host: host} = uri}
         when is_binary(host) <- URI.new(catalog_url),
         true <- host != "",
         true <- uri.port in 1..65_535,
         {:ok, path} <- frontman_path(uri.path || "/", uri.query) do
      {:ok, URI.to_string(%{uri | path: path, query: nil})}
    else
      _ -> :error
    end
  end

  defp frontman_path(path, nil) do
    case Regex.run(~r{\A(.*)/wp-json/frontman/v1/tools/?\z}, path, capture: :all_but_first) do
      [base] -> {:ok, base <> "/frontman"}
      nil -> :error
    end
  end

  defp frontman_path(path, query) do
    route = ~r{\Arest_route=(?:/|%2[fF])frontman(?:/|%2[fF])v1(?:/|%2[fF])tools(?:/|%2[fF])?\z}

    case Regex.match?(route, query) do
      true ->
        base = String.trim_trailing(path, "/")
        controller = if String.ends_with?(base, "/index.php"), do: "", else: "/index.php"
        {:ok, base <> controller <> "/frontman"}

      false ->
        :error
    end
  end

  defp catalog_batches(groups) do
    Stream.unfold(groups, fn
      [] ->
        nil

      groups ->
        {batch, remaining} = Enum.unzip(Enum.map(groups, fn [id | rest] -> {id, rest} end))
        {batch, Enum.reject(remaining, &(&1 == []))}
    end)
  end

  defp fetch_catalog(connections, id, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    result =
      case Map.fetch(connections, id) do
        {:ok, connection} when remaining > 0 ->
          request_connection(connection, :get, nil, remaining)

        _ ->
          {:error, :connection_failed}
      end

    {id, result}
  end

  defp request_site(scope, site_id, method, body, timeout) do
    with {:ok, site_id} <- Ecto.UUID.cast(site_id),
         %Connection{} = connection <-
           scope |> Scope.user_id() |> Connection.owned() |> Repo.get(site_id) do
      request_connection(connection, method, body, timeout)
    else
      _ -> {:error, :connection_failed}
    end
  end

  defp request_connection(connection, method, body, timeout) do
    url =
      case method do
        :get -> connection.catalog_url
        :post -> connection.call_url
      end

    request(url, connection.username, connection.password, method, body, timeout)
  end

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
    started = System.monotonic_time(:millisecond)
    client = Req.new(Application.get_env(:frontman_server, __MODULE__, plugins: [PublicURL]))

    task =
      Task.async(fn ->
        Req.request(client,
          method: method,
          url: url,
          auth: {:basic, "#{username}:#{password}"},
          json: body,
          redirect: false,
          retry: false,
          receive_timeout: min(timeout, 10_000),
          decode_body: false,
          into: fn {:data, data}, {req, resp} ->
            case byte_size(resp.body) + byte_size(data) <= 1_000_000 do
              true -> {:cont, {req, %{resp | body: resp.body <> data}}}
              false -> {:halt, {req, %{resp | status: 0, body: ""}}}
            end
          end
        )
      end)

    {result, outcome, status} =
      request_result(Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill))

    request_event(method, outcome, status, started)
    result
  end

  defp request_result({:ok, {:ok, %{status: 200, body: response}}}) do
    result = Jason.decode(response)
    outcome = if match?({:ok, _}, result), do: :ok, else: :invalid_json
    {result, outcome, 200}
  end

  defp request_result({:ok, {:ok, %{status: status}}} = result),
    do: {{:error, :request_failed}, request_failure(result), status}

  defp request_result(result), do: {{:error, :request_failed}, request_failure(result), 0}

  defp request_failure({:ok, {:ok, %{status: 0}}}), do: :oversized_result
  defp request_failure({:ok, {:ok, %{status: _}}}), do: :non_200
  defp request_failure({:ok, {:error, %Req.TransportError{reason: :timeout}}}), do: :timeout
  defp request_failure({:ok, {:error, _}}), do: :transport
  defp request_failure(nil), do: :timeout
  defp request_failure(_), do: :task_exit

  defp request_event(method, outcome, status, started) do
    kind = if method == :get, do: :catalog, else: :call

    :telemetry.execute(
      [:frontman_server, :wordpress, kind, :stop],
      %{duration_ms: max(System.monotonic_time(:millisecond) - started, 0), status_code: status},
      %{outcome: outcome}
    )
  end
end
