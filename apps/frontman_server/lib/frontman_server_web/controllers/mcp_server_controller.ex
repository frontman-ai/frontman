# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.McpServerController do
  use FrontmanServerWeb, :controller

  def metadata(conn, _params) do
    config = Application.fetch_env!(:frontman_server, :mcp_server)

    case {config[:resource], config[:issuer]} do
      {resource, issuer} when is_binary(resource) and is_binary(issuer) ->
        json(conn, %{resource: resource, authorization_servers: [issuer]})

      _ ->
        send_resp(conn, 503, "")
    end
  end
end
