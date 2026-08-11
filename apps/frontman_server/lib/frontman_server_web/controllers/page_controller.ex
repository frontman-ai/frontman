# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

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
