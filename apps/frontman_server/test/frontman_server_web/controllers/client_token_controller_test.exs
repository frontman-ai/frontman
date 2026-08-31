defmodule FrontmanServerWeb.ClientTokenControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  require Phoenix.ChannelTest

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.UserToken
  alias FrontmanServer.Repo

  test "deletes the authenticated embedded client token", %{conn: conn} do
    user = user_fixture()

    conn = put_embedded_client_bearer(conn, user)
    [user_token] = Repo.all(UserToken.by_embedded_client_user(user.id))

    conn = delete(conn, ~p"/api/client-token")

    assert response(conn, 204) == ""
    assert Repo.get(UserToken, user_token.id) == nil
  end

  test "revoked token cannot reconnect", %{conn: conn} do
    user = user_fixture()
    token = Accounts.generate_embedded_client_token(user, "https://customer.example")

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> delete(~p"/api/client-token")

    assert response(conn, 204) == ""

    assert :error =
             Phoenix.ChannelTest.connect(FrontmanServerWeb.UserSocket, %{},
               connect_info: %{auth_token: token}
             )
  end

  test "does not delete other embedded client tokens", %{conn: conn} do
    user = user_fixture()
    other_token = Accounts.generate_embedded_client_token(user, "https://other.example")

    conn =
      conn
      |> put_embedded_client_bearer(user)
      |> delete(~p"/api/client-token")

    assert response(conn, 204) == ""
    assert Accounts.get_scope_by_embedded_client_token(other_token) != nil
  end

  test "requires bearer auth", %{conn: conn} do
    conn = delete(conn, ~p"/api/client-token")

    assert json_response(conn, 401) == %{"error" => "authentication_required"}
  end
end
