defmodule FrontmanServerWeb.HealthController do
  use FrontmanServerWeb, :controller

  alias Ecto.Adapters.SQL

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def ready(conn, _params) do
    case SQL.query(FrontmanServer.Repo, "SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "ready", database: "connected"})

      {:error, _} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: "unavailable"})
    end
  end
end
