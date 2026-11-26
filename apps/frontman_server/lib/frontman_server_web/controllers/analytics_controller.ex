defmodule FrontmanServerWeb.AnalyticsController do
  use FrontmanServerWeb, :controller

  alias FrontmanServerWeb.Analytics

  def page_view(conn, %{"receipt" => receipt}) do
    case Analytics.record_page_view(conn, receipt) do
      :ok -> send_resp(conn, :no_content, "")
      {:error, :invalid_receipt} -> send_resp(conn, :bad_request, "")
    end
  end

  def page_view(conn, _params), do: send_resp(conn, :bad_request, "")
end
