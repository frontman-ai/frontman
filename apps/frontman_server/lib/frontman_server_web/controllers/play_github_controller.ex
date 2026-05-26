# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithubController do
  use FrontmanServerWeb, :controller

  def index(conn, _params) do
    html(
      conn,
      "PlayGithub local subdomain is routed for #{conn.assigns.current_scope.user.email}"
    )
  end
end
