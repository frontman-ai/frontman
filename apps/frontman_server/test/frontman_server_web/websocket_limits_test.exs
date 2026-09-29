defmodule FrontmanServerWeb.WebSocketLimitsTest do
  use ExUnit.Case, async: true

  alias FrontmanServerWeb.Endpoint

  def init(:plug), do: :plug
  def init(:socket), do: {:ok, :socket}

  def call(conn, :plug) do
    {_, _, socket_options} =
      Enum.find(Endpoint.__sockets__(), fn {path, _, _} -> path == "/socket" end)

    conn
    |> WebSockAdapter.upgrade(__MODULE__, :socket, socket_options[:websocket])
    |> Plug.Conn.halt()
  end

  def handle_in({data, opcode: :text}, state),
    do: {:push, {:text, Integer.to_string(byte_size(data))}, state}

  def terminate(_reason, _state), do: :ok

  @tag capture_log: true
  test "bounded masked frames and fragmented messages do not affect another connection" do
    options = Endpoint.config(:http)[:websocket_options]
    assert options[:max_fragmented_message_size] == 8_000_000

    server =
      start_supervised!({Bandit, plug: {__MODULE__, :plug}, port: 0, websocket_options: options})

    {:ok, {_, port}} = ThousandIsland.listener_info(server)
    healthy = connect(port)
    boundary = connect(port)
    payload = String.duplicate("a", 8_000_000)

    send_frame(boundary, 1, 1, payload)
    assert receive_frame(boundary) == {1, "8000000"}
    send_frame(boundary, 0, 1, binary_part(payload, 0, 4_000_000))
    send_frame(boundary, 1, 0, binary_part(payload, 0, 4_000_000))
    assert receive_frame(boundary) == {1, "8000000"}

    oversized = connect(port)
    send_frame(oversized, 1, 1, payload <> "a")
    assert {8, <<1009::16, _::binary>>} = receive_frame(oversized)
    send_frame(boundary, 0, 1, binary_part(payload, 0, 4_000_000))
    send_frame(boundary, 1, 0, binary_part(payload, 0, 4_000_000) <> "a")
    assert {8, <<1009::16, _::binary>>} = receive_frame(boundary)
    send_frame(healthy, 1, 1, "ok")
    assert receive_frame(healthy) == {1, "2"}
  end

  defp connect(port) do
    {:ok, socket} =
      :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false, packet: :http_bin], 5_000)

    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
      )

    assert {:ok, {:http_response, _, 101, _}} = :gen_tcp.recv(socket, 0, 5_000)

    assert :done ==
             Enum.reduce_while(1..20, :headers, fn _, _ ->
               case :gen_tcp.recv(socket, 0, 5_000) do
                 {:ok, :http_eoh} -> {:halt, :done}
                 {:ok, {:http_header, _, _, _, _}} -> {:cont, :headers}
               end
             end)

    :ok = :inet.setopts(socket, packet: :raw)
    socket
  end

  defp send_frame(socket, fin, opcode, data) do
    header =
      case byte_size(data) do
        length when length <= 125 -> <<fin::1, 0::3, opcode::4, 1::1, length::7, 0::32>>
        length -> <<fin::1, 0::3, opcode::4, 1::1, 127::7, length::64, 0::32>>
      end

    :ok = :gen_tcp.send(socket, [header, data])
  end

  defp receive_frame(socket) do
    {:ok, <<1::1, 0::3, opcode::4, 0::1, length::7>>} = :gen_tcp.recv(socket, 2, 5_000)
    {:ok, payload} = :gen_tcp.recv(socket, length, 5_000)
    {opcode, payload}
  end
end
