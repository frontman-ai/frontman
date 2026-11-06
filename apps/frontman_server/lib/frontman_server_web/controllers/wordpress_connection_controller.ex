defmodule FrontmanServerWeb.WordPressConnectionController do
  use FrontmanServerWeb, :controller

  def status(conn, %{"catalog_url" => catalog_url})
      when is_binary(catalog_url) and catalog_url != "" do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> json(%{
      connected: FrontmanServer.WordPress.connected?(conn.assigns.current_scope, catalog_url)
    })
  end

  def status(conn, _params) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(:bad_request)
    |> json(%{error: "catalog_url is required"})
  end

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
