defmodule FrontmanServerWeb.OpenAIAdsAttributionController do
  use FrontmanServerWeb, :controller
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.OpenAIAds
  alias FrontmanServerWeb.OpenAIAdsCookie

  def create(conn, _params) do
    case OpenAIAds.grant(scope(conn), OpenAIAdsCookie.id(conn), conn.private.openai_ads_params) do
      {:ok, consent} ->
        conn |> OpenAIAdsCookie.put(consent.id, consent.expires_at) |> send_resp(204, "")

      {:error, _invalid} ->
        send_resp(conn, 422, "")
    end
  end

  def delete(conn, _params) do
    :ok = OpenAIAds.withdraw(scope(conn), OpenAIAdsCookie.id(conn))
    conn |> OpenAIAdsCookie.delete() |> send_resp(204, "")
  end

  defp scope(%{assigns: %{current_scope: nil}}), do: %Scope{}
  defp scope(conn), do: conn.assigns.current_scope
end
