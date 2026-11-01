# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.McpServerController do
  use FrontmanServerWeb, :controller

  def metadata(conn, _params) do
    FrontmanServerWeb.MCP.metadata(conn, [])
  end
end
