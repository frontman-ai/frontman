defmodule FrontmanServerWeb.WordPressConnectionController do
  use FrontmanServerWeb, :controller

  alias FrontmanServerWeb.Analytics

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
    conn =
      conn
      |> put_resp_header("cache-control", "no-store")
      |> Analytics.track("site_connection_started", %{framework: "wordpress"})

    case FrontmanServer.WordPress.connect(conn.assigns.current_scope, params) do
      {:ok, id} ->
        conn
        |> Analytics.track("site_connection_completed", %{framework: "wordpress"})
        |> json(%{id: id})

      {:error, _} ->
        conn
        |> Analytics.track("site_connection_failed", %{
          framework: "wordpress",
          reason_code: "connection_failed"
        })
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Connection failed"})
    end
  end
end
