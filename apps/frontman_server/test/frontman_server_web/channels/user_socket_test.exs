defmodule FrontmanServerWeb.UserSocketTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.UserSocket

  test "socket token is bound to the current browser session" do
    user = FrontmanServer.Test.Fixtures.Accounts.user_fixture()
    session_token = Accounts.generate_user_session_token(user)
    session_id = Accounts.user_session_id(session_token)
    socket_token = Phoenix.Token.sign(@endpoint, "user socket", {user.id, session_id})

    assert {:ok, socket} = connect(UserSocket, %{"token" => socket_token})
    assert socket.assigns.scope.user.id == user.id
    assert UserSocket.id(socket) == "user_sessions:#{session_id}"
  end

  test "deleted browser session cannot authenticate a new socket" do
    user = FrontmanServer.Test.Fixtures.Accounts.user_fixture()
    session_token = Accounts.generate_user_session_token(user)
    session_id = Accounts.user_session_id(session_token)
    socket_token = Phoenix.Token.sign(@endpoint, "user socket", {user.id, session_id})

    :ok = Accounts.delete_user_session_token(session_token)

    assert {:ok, socket} = connect(UserSocket, %{"token" => socket_token})
    refute Map.has_key?(socket.assigns, :scope)
    assert UserSocket.id(socket) == nil
  end
end
