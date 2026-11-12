defmodule FrontmanServerWeb.PasswordLoginDevTest do
  use FrontmanServerWeb.ConnCase, async: false

  test "development routes retain the default password form", %{conn: conn} do
    previous = Application.get_env(:frontman_server, :dev_routes)
    Application.put_env(:frontman_server, :dev_routes, true)
    on_exit(fn -> Application.put_env(:frontman_server, :dev_routes, previous) end)

    response = conn |> get(~p"/users/log-in") |> html_response(200)
    assert response =~ ~s(id="login-form")
    assert response =~ ~s(type="password")
  end
end
