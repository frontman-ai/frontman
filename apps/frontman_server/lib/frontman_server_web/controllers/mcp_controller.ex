# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.McpController do
  use FrontmanServerWeb, :controller

  def metadata(conn, _params) do
    case FrontmanServerWeb.McpConfig.fetch() do
      {:ok, resource, issuer} ->
        json(conn, %{resource: resource, authorization_servers: [issuer]})

      {:error, :invalid_configuration} ->
        send_resp(conn, 503, "")
    end
  end
end
