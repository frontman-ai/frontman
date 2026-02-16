defmodule FrontmanServerWeb.UserRegistrationControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.AccountsFixtures

  describe "GET /users/register" do
    test "redirects to login page (registration disabled)", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)
      # Registration is disabled, /users/register now renders the login page
      assert response =~ "Sign in to Frontman"
      assert response =~ "Continue with GitHub"
      assert response =~ "Continue with Google"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == ~p"/"
    end
  end
end
