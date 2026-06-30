# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.HealthController do
  use FrontmanServerWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def ready(conn, _params) do
    case FrontmanServer.Drain.ready?() do
      true ->
        json(conn, %{status: "ready"})

      false ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "draining"})
    end
  end
end
