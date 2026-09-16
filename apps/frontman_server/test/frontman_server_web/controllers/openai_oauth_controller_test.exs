defmodule FrontmanServerWeb.OpenAIOAuthControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  setup do
    user = AccountsFixtures.user_fixture()

    %{embedded_auth: embedded_client_auth(user), user: user}
  end

  describe "GET /api/oauth/openai/status" do
    test "returns OAuth status for a bearer-authenticated user", %{
      conn: conn,
      embedded_auth: auth
    } do
      conn = bearer_get(conn, auth, ~p"/api/oauth/openai/status")

      assert %{"connected" => false} == json_response(conn, 200)
    end

    test "returns unauthorized without a bearer token" do
      conn = get(build_conn(), ~p"/api/oauth/openai/status")

      assert json_response(conn, 401)["error"] == "authentication_required"
    end

    test "returns unauthorized for session-only authentication", %{user: user} do
      conn =
        build_conn()
        |> log_in_user(user)
        |> get(~p"/api/oauth/openai/status")

      assert json_response(conn, 401)["error"] == "authentication_required"
    end
  end
end
