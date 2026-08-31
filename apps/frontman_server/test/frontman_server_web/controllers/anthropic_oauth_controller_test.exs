defmodule FrontmanServerWeb.AnthropicOAuthControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    conn = put_embedded_client_bearer(conn, user)

    %{conn: conn, user: user}
  end

  describe "GET /api/oauth/anthropic/status" do
    test "returns OAuth status for a bearer-authenticated user", %{conn: conn} do
      conn = get(conn, ~p"/api/oauth/anthropic/status")

      assert %{"connected" => false} == json_response(conn, 200)
    end

    test "returns unauthorized for session-only authentication", %{user: user} do
      conn =
        build_conn()
        |> log_in_user(user)
        |> get(~p"/api/oauth/anthropic/status")

      assert json_response(conn, 401)["error"] == "authentication_required"
    end
  end

  describe "GET /api/oauth/anthropic/authorize-url" do
    test "returns an authorize URL for a bearer-authenticated request", %{conn: conn} do
      conn = get(conn, ~p"/api/oauth/anthropic/authorize-url")
      response = json_response(conn, 200)

      assert is_binary(response["authorize_url"])
      assert is_binary(response["verifier"])
    end

    test "returns unauthorized without a bearer token" do
      conn = get(build_conn(), ~p"/api/oauth/anthropic/authorize-url")

      assert json_response(conn, 401)["error"] == "authentication_required"
    end
  end
end
