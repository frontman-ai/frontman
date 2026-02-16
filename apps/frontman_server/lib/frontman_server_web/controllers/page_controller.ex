defmodule FrontmanServerWeb.PageController do
  use FrontmanServerWeb, :controller

  # In production, the root URL (api.frontman.sh) redirects to the marketing site.
  # In dev, redirect unauthenticated visitors to the sign-in page.
  # Authenticated users in dev see a simple "you're signed in" page
  # (avoids redirect loop with signed_in_path -> / -> /users/log-in).
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
