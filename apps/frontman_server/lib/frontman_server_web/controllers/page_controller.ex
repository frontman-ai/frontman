defmodule FrontmanServerWeb.PageController do
  use FrontmanServerWeb, :controller

  def home(conn, _params) do
    if Application.get_env(:frontman_server, :dev_routes) do
      if conn.assigns[:current_scope] do
        redirect(conn, to: ~p"/users/settings")
      else
        redirect(conn, to: ~p"/users/log-in")
      end
    else
      redirect(conn, external: "https://frontman.sh")
    end
  end
end
