defmodule FrontmanServer.CowboySecurityTest do
  use ExUnit.Case, async: true

  @behaviour :cowboy_handler

  @impl true
  def init(request, test_pid) do
    send(test_pid, {:request_received, self()})

    receive do
      :release -> {:ok, :cowboy_req.reply(200, %{}, "ok", request), test_pid}
    after
      5_000 -> {:ok, :cowboy_req.reply(500, %{}, "timeout", request), test_pid}
    end
  end

  test "a held GET does not buffer a pipelined flood" do
    {:ok, _} = Application.ensure_all_started(:cowboy)
    listener = __MODULE__
    dispatch = :cowboy_router.compile([{:_, [{"/hold", __MODULE__, self()}]}])

    {:ok, _} =
      :cowboy.start_clear(listener, %{socket_opts: [ip: {127, 0, 0, 1}, port: 0]}, %{
        env: %{dispatch: dispatch}
      })

    on_exit(fn -> :cowboy.stop_listener(listener) end)
    port = :ranch.get_port(listener)

    {:ok, socket} =
      :gen_tcp.connect(
        {127, 0, 0, 1},
        port,
        [:binary, active: false, send_timeout: 500, send_timeout_close: false],
        2_000
      )

    on_exit(fn -> :gen_tcp.close(socket) end)
    assert :ok = :gen_tcp.send(socket, "GET /hold HTTP/1.1\r\nhost: localhost\r\n\r\n")
    assert_receive {:request_received, handler}, 2_000
    [connection] = :ranch.procs(listener, :connections)
    result = :gen_tcp.send(socket, :binary.copy("X", 4 * 1024 * 1024))
    assert result in [:ok, {:error, :timeout}]
    Process.sleep(1_000)
    assert {:binary, binaries} = Process.info(connection, :binary)
    assert Enum.sum(for {_, size, _} <- binaries, do: size) < 1024 * 1024
    send(handler, :release)
    assert {:ok, "HTTP/1.1 200"} = :gen_tcp.recv(socket, 12, 2_000)
  end
end
