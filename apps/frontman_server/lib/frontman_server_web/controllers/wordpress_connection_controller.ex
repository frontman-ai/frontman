defmodule FrontmanServerWeb.WordPressConnectionController do
  use FrontmanServerWeb, :controller

  def create(conn, params) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    case FrontmanServer.WordPress.connect(conn.assigns.current_scope, params) do
      {:ok, id} ->
        json(conn, %{id: id})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Connection failed"})
    end
  end
end
