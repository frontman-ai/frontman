defmodule FrontmanServerWeb.PageControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  test "GET / redirects to frontman.sh", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "https://frontman.sh"
  end
end
