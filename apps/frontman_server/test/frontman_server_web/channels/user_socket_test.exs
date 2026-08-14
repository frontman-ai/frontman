defmodule FrontmanServerWeb.UserSocketTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.UserSocket

  test "socket token is bound to the current browser session" do
    user = FrontmanServer.Test.Fixtures.Accounts.user_fixture()
    session_token = Accounts.generate_user_session_token(user)
    {^user, user_token_id} = Accounts.get_socket_session(session_token)
    browser_session_id = "browser-session"

    socket_token =
      Phoenix.Token.sign(@endpoint, "user socket", {user.id, user_token_id, browser_session_id})

    assert {:ok, socket} = connect(UserSocket, %{"token" => socket_token})
    assert socket.assigns.scope.user.id == user.id
    assert socket.assigns.user_token_id == user_token_id
    assert UserSocket.id(socket) == "user_sessions:#{browser_session_id}"
  end

  test "deleted browser session cannot authenticate a new socket" do
    user = FrontmanServer.Test.Fixtures.Accounts.user_fixture()
    session_token = Accounts.generate_user_session_token(user)
    {^user, user_token_id} = Accounts.get_socket_session(session_token)

    socket_token =
      Phoenix.Token.sign(@endpoint, "user socket", {user.id, user_token_id, "browser-session"})

    :ok = Accounts.delete_user_session_token(session_token)

    assert {:ok, socket} = connect(UserSocket, %{"token" => socket_token})
    refute Map.has_key?(socket.assigns, :scope)
    assert UserSocket.id(socket) == nil
  end

  test "rotated session tokens keep the browser socket identity" do
    user = FrontmanServer.Test.Fixtures.Accounts.user_fixture()
    first_token = Accounts.generate_user_session_token(user)
    second_token = Accounts.generate_user_session_token(user)
    {^user, first_token_id} = Accounts.get_socket_session(first_token)
    {^user, second_token_id} = Accounts.get_socket_session(second_token)
    browser_session_id = "stable-browser-session"

    first_socket_token =
      Phoenix.Token.sign(
        @endpoint,
        "user socket",
        {user.id, first_token_id, browser_session_id}
      )

    second_socket_token =
      Phoenix.Token.sign(
        @endpoint,
        "user socket",
        {user.id, second_token_id, browser_session_id}
      )

    assert {:ok, first_socket} = connect(UserSocket, %{"token" => first_socket_token})
    assert {:ok, second_socket} = connect(UserSocket, %{"token" => second_socket_token})
    assert UserSocket.id(first_socket) == UserSocket.id(second_socket)
  end
end
