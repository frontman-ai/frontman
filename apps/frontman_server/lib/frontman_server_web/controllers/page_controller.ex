# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PageController do
  use FrontmanServerWeb, :controller

  # In production, the root URL (api.frontman.sh) redirects to the marketing site.
  # In dev, redirect unauthenticated visitors to the sign-in page.
  # Authenticated users in dev see a simple "you're signed in" page.
  # Do not redirect to sudo-only routes here; expired sudo sessions would loop.
  def home(conn, _params) do
    if Application.get_env(:frontman_server, :dev_routes) do
      case conn.assigns[:current_scope] do
        %{user: user} when not is_nil(user) ->
          text(conn, "Signed in to Frontman")

        _ ->
          redirect(conn, to: ~p"/users/log-in")
      end
    else
      redirect(conn, external: "https://frontman.sh")
    end
  end
end
