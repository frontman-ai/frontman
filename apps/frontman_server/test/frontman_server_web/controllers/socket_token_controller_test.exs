defmodule FrontmanServerWeb.SocketTokenControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Accounts

  setup :register_and_log_in_user

  test "issues a database-backed token with a stable browser session identity", %{
    conn: conn,
    user: user
  } do
    conn = get(conn, ~p"/api/socket-token")
    %{"token" => socket_token} = json_response(conn, 200)
    browser_session_id = get_session(conn, :socket_session_id)
    session_token = get_session(conn, :user_token)
    {^user, user_token_id} = Accounts.get_socket_session(session_token)
    user_id = user.id

    assert {:ok, {^user_id, ^user_token_id, ^browser_session_id}} =
             Phoenix.Token.verify(@endpoint, "user socket", socket_token, max_age: 300)
  end

  test "returns unauthorized when logout revokes session after pipeline authentication", %{
    conn: conn
  } do
    conn = FrontmanServerWeb.UserAuth.fetch_current_scope_for_user(conn, [])
    session_token = get_session(conn, :user_token)
    :ok = Accounts.delete_user_session_token(session_token)

    conn = FrontmanServerWeb.SocketTokenController.show(conn, %{})

    assert json_response(conn, 401) == %{"error" => "Not authenticated"}
  end
end
