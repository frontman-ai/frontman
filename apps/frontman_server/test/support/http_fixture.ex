defmodule FrontmanServer.Test.HTTPFixture do
  @moduledoc "Serves fixture responses over a real Bandit listener for one test."

  import ExUnit.Assertions
  import ExUnit.Callbacks

  def start!(routes, respond) when is_map(routes) and is_function(respond, 1) do
    counts = :atomics.new(map_size(routes), [])
    indexes = routes |> Map.keys() |> Enum.with_index(1) |> Map.new()

    on_exit(fn ->
      for {route, expected} <- routes, expected != :any do
        actual = :atomics.get(counts, Map.fetch!(indexes, route))

        assert actual == expected,
               "Expected #{expected} requests for #{inspect(route)}, got #{actual}"
      end
    end)

    server =
      start_supervised!(
        {Bandit,
         plug: {__MODULE__, {indexes, counts, respond}},
         ip: {127, 0, 0, 1},
         port: 0,
         startup_log: false},
        id: make_ref()
      )

    {:ok, {_, port}} = ThousandIsland.listener_info(server)
    "http://127.0.0.1:#{port}"
  end

  def init(options), do: options

  def call(conn, {indexes, counts, respond}) do
    index = Map.fetch!(indexes, {conn.method, conn.request_path})
    :atomics.add(counts, index, 1)
    respond.(conn)
  end
end
