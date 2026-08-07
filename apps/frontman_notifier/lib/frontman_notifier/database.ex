defmodule FrontmanNotifier.Database do
  @moduledoc """
  Small Postgrex wrapper for local production database reads.
  """

  alias FrontmanNotifier.Config

  @query_timeout_ms 15_000

  @spec with_connection((pid() -> result)) :: result when result: term()
  def with_connection(callback) when is_function(callback, 1) do
    conn = connect!()

    try do
      callback.(conn)
    after
      GenServer.stop(conn, :normal, 5_000)
    end
  end

  @spec query_maps!(pid(), String.t(), list()) :: list(map())
  def query_maps!(conn, sql, params \\ [])
      when is_pid(conn) and is_binary(sql) and is_list(params) do
    conn
    |> Postgrex.query!(sql, params, timeout: @query_timeout_ms)
    |> rows_to_maps()
  end

  defp connect! do
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, conn} = Config.database_url!() |> database_opts() |> Postgrex.start_link()
    conn
  end

  defp database_opts(url) when is_binary(url) do
    uri = URI.parse(url)
    {username, password} = credentials(uri.userinfo)

    [
      hostname: uri.host || "localhost",
      port: uri.port || 5432,
      database: database_name(uri.path),
      username: username,
      password: password,
      ssl: Config.database_ssl?()
    ]
  end

  defp credentials(nil), do: {nil, nil}

  defp credentials(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [username, password] -> {URI.decode(username), URI.decode(password)}
      [username] -> {URI.decode(username), nil}
    end
  end

  defp database_name(nil), do: raise("Database URL path is required")
  defp database_name("/"), do: raise("Database URL path is required")
  defp database_name(path), do: String.trim_leading(path, "/")

  defp rows_to_maps(%Postgrex.Result{columns: columns, rows: rows}) do
    Enum.map(rows, fn row -> columns |> Enum.zip(row) |> Map.new() end)
  end
end
