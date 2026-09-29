defmodule FrontmanServerWeb.UserSocketTest do
  use FrontmanServerWeb.ChannelCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias Bandit.WebSocket.Frame
  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.UserSocket

  test "endpoint enables bounded authenticated websocket transport" do
    assert {"/socket", UserSocket, socket_opts} =
             Enum.find(FrontmanServerWeb.Endpoint.__sockets__(), fn {path, module, _opts} ->
               path == "/socket" and module == UserSocket
             end)

    assert socket_opts[:auth_token] == true
    assert socket_opts[:websocket] == [check_origin: false, max_frame_size: 8_000_014]

    assert FrontmanServerWeb.Endpoint.config(:http)[:websocket_options][
             :max_fragmented_message_size
           ] ==
             8_000_000

    limit = socket_opts[:websocket][:max_frame_size]

    assert {:ok, {14, 8_000_000}} =
             Frame.header_and_payload_length(
               <<0x81, 0xFF, 8_000_000::64, 0::32>>,
               limit
             )

    assert {:error, :max_frame_size_exceeded} =
             Frame.header_and_payload_length(
               <<0x81, 0xFF, 8_000_001::64, 0::32>>,
               limit
             )
  end

  test "connects with valid embedded client auth token" do
    user = user_fixture()
    token = Accounts.generate_embedded_client_token(user, "https://customer.example")

    assert {:ok, socket} =
             connect(UserSocket, %{"origin" => "https://customer.example"},
               connect_info: %{auth_token: token}
             )

    assert socket.assigns.scope.user.id == user.id
    assert is_binary(socket.assigns.embedded_client_token_id)
    assert UserSocket.id(socket) == "client_token:#{socket.assigns.embedded_client_token_id}"
  end

  test "rejects missing auth token" do
    assert :error = connect(UserSocket, %{}, connect_info: %{})
  end

  test "rejects invalid auth token" do
    assert :error =
             connect(UserSocket, %{"origin" => "https://customer.example"},
               connect_info: %{auth_token: "invalid"}
             )
  end

  test "rejects wrong origin" do
    user = user_fixture()
    token = Accounts.generate_embedded_client_token(user, "https://customer.example")

    assert :error =
             connect(UserSocket, %{"origin" => "https://evil.example"},
               connect_info: %{auth_token: token}
             )
  end

  test "rejects legacy token params" do
    user = user_fixture()
    token = Phoenix.Token.sign(FrontmanServerWeb.Endpoint, "user socket", user.id)

    assert :error = connect(UserSocket, %{"token" => token}, connect_info: %{})
  end
end
