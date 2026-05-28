defmodule FrontmanServerWeb.PageControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  test "GET / redirects to frontman.sh", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "https://frontman.sh"
  end

  describe "GET / with dev routes" do
    setup do
      previous_dev_routes = Application.get_env(:frontman_server, :dev_routes)
      Application.put_env(:frontman_server, :dev_routes, true)

      on_exit(fn ->
        Application.put_env(:frontman_server, :dev_routes, previous_dev_routes)
      end)
    end

    test "redirects unauthenticated users to log in", %{conn: conn} do
      conn = get(conn, ~p"/")

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "renders signed-in page without hitting sudo-only settings", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        conn
        |> get(~p"/")

      assert text_response(conn, 200) == "Signed in to Frontman"
    end
  end
end
