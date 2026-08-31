defmodule FrontmanServerWeb.UserMeControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  describe "GET /api/user/me" do
    test "returns the current user for an embedded client bearer token", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> put_embedded_client_bearer(user)
        |> get(~p"/api/user/me")

      assert %{"id" => user.id, "email" => user.email, "name" => user.name} ==
               json_response(conn, 200)
    end

    test "returns unauthorized without bearer token", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/api/user/me")

      assert json_response(conn, 401)["error"] == "authentication_required"
    end
  end
end
