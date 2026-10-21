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

    assert socket_opts[:websocket] == [
             check_origin: false,
             connect_info: [:x_headers],
             max_frame_size: 8_000_014
           ]

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
               connect_info: connect_info(token, "https://customer.example")
             )

    assert socket.assigns.scope.user.id == user.id
    assert is_binary(socket.assigns.embedded_client_token_id)
    assert UserSocket.id(socket) == "client_token:#{socket.assigns.embedded_client_token_id}"
  end

  test "rejects missing auth token" do
    assert :error = connect(UserSocket, %{}, connect_info: %{})

    assert :error =
             connect(UserSocket, %{"origin" => "https://customer.example"},
               connect_info: %{
                 x_headers: [{"x-frontman-socket-origin", "https://customer.example"}]
               }
             )
  end

  test "rejects invalid auth token" do
    assert :error =
             connect(UserSocket, %{"origin" => "https://customer.example"},
               connect_info: connect_info("invalid", "https://customer.example")
             )
  end

  test "rejects wrong origin" do
    user = user_fixture()
    token = Accounts.generate_embedded_client_token(user, "https://customer.example")

    assert :error =
             connect(UserSocket, %{"origin" => "https://evil.example"},
               connect_info: connect_info(token, "https://evil.example")
             )
  end

  test "rejects legacy token params" do
    user = user_fixture()
    token = Phoenix.Token.sign(FrontmanServerWeb.Endpoint, "user socket", user.id)

    assert :error = connect(UserSocket, %{"token" => token}, connect_info: %{})
  end

  test "rejects a claimed approved origin with a different handshake origin" do
    token = Accounts.generate_embedded_client_token(user_fixture(), "https://customer.example")

    assert :error =
             connect(UserSocket, %{"origin" => "https://customer.example"},
               connect_info: connect_info(token, "https://evil.example")
             )
  end

  test "requires a valid actual origin even with a valid bearer and claim" do
    token = Accounts.generate_embedded_client_token(user_fixture(), "https://customer.example")

    for headers <- [
          [],
          [{"x-frontman-socket-origin", "null"}],
          [{"x-frontman-socket-origin", "https://customer.example/path"}],
          [
            {"x-frontman-socket-origin", "https://customer.example"},
            {"x-frontman-socket-origin", "https://customer.example"}
          ]
        ] do
      assert :error =
               connect(UserSocket, %{"origin" => "https://customer.example"},
                 connect_info: %{auth_token: token, x_headers: headers}
               )
    end
  end

  test "normalizes matching origins and preserves local development origins" do
    for {approved, claimed, actual} <- [
          {"https://customer.example", "https://CUSTOMER.example:443",
           "https://customer.example"},
          {"http://localhost:5173", "http://localhost:5173", "http://localhost:5173"}
        ] do
      token = Accounts.generate_embedded_client_token(user_fixture(), approved)

      assert {:ok, _socket} =
               connect(UserSocket, %{"origin" => claimed},
                 connect_info: connect_info(token, actual)
               )
    end
  end

  test "endpoint uses actual Origin and overwrites forged internal headers before dispatch" do
    token = Accounts.generate_embedded_client_token(user_fixture(), "https://customer.example")

    assert handshake(token, "https://customer.example", [
             {"origin", "https://CUSTOMER.example:443"},
             {"x-frontman-socket-origin", "https://evil.example"}
           ]).state == :upgraded

    assert handshake(token, "https://customer.example", [
             {"origin", "https://evil.example"},
             {"x-frontman-socket-origin", "https://customer.example"}
           ]).status == 403

    assert handshake(token, "https://evil.example", [
             {"origin", "https://evil.example"}
           ]).status == 403

    assert handshake("invalid", "https://customer.example", [
             {"origin", "https://customer.example"}
           ]).status == 403

    for headers <- [
          [{"x-frontman-socket-origin", "https://customer.example"}],
          [{"origin", "null"}],
          [{"origin", ""}],
          [{"origin", "https://customer.example/path"}],
          [{"origin", "https://customer.example, https://evil.example"}],
          [{"origin", "https://customer.example"}, {"origin", "https://customer.example"}]
        ] do
      assert handshake(token, "https://customer.example", headers).status == 403
    end
  end

  defp connect_info(token, origin) do
    %{auth_token: token, x_headers: [{"x-frontman-socket-origin", origin}]}
  end

  defp handshake(token, claimed_origin, headers) do
    conn =
      Plug.Test.conn(
        :get,
        "/socket/websocket?" <>
          URI.encode_query(%{
            "origin" => claimed_origin,
            "vsn" => "2.0.0"
          })
      )

    conn = %{
      conn
      | req_headers: [
          {"host", "www.example.com"},
          {"connection", "upgrade"},
          {"upgrade", "websocket"},
          {"sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ=="},
          {"sec-websocket-version", "13"},
          {"sec-websocket-protocol",
           "phoenix, base64url.bearer.phx.#{Base.encode64(token, padding: false)}"}
          | headers
        ]
    }

    FrontmanServerWeb.Endpoint.call(conn, FrontmanServerWeb.Endpoint.init([]))
  end
end
