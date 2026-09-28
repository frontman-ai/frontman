# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.SupportQuestionController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Support

  def create(conn, _params) do
    case Support.submit_question(conn.body_params) do
      {:ok, submission_id} ->
        conn
        |> put_status(:accepted)
        |> json(%{status: "queued", submitted: true, submission_id: submission_id})

      {:error, :invalid_question} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Provide only a nonblank question of at most 4000 UTF-16 code units."})

      {:error, :unavailable} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unavailable", submitted: false})

      {:error, :enqueue_failed} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "unknown", submitted: nil})
    end
  end
end
