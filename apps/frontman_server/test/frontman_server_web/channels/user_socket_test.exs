defmodule FrontmanServerWeb.UserSocketTest do
  use FrontmanServerWeb.ChannelCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.UserSocket

  test "endpoint enables Phoenix websocket auth token transport" do
    assert {"/socket", UserSocket, socket_opts} =
             Enum.find(FrontmanServerWeb.Endpoint.__sockets__(), fn {path, module, _opts} ->
               path == "/socket" and module == UserSocket
             end)

    assert socket_opts[:auth_token] == true
    assert socket_opts[:websocket] == [check_origin: false]
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
