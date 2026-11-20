defmodule FrontmanServerWeb.OpenAIAdsAttributionController do
  use FrontmanServerWeb, :controller
  alias FrontmanServer.OpenAIAds
  alias FrontmanServerWeb.OpenAIAdsCookie

  def create(conn, _params) do
    case OpenAIAds.grant(OpenAIAdsCookie.id(conn), conn.private.openai_ads_params, user_id(conn)) do
      {:ok, consent} ->
        conn |> OpenAIAdsCookie.put(consent.id, consent.expires_at) |> send_resp(204, "")

      {:error, _invalid} ->
        send_resp(conn, 422, "")
    end
  end

  def delete(conn, _params) do
    :ok = OpenAIAds.withdraw(OpenAIAdsCookie.id(conn), user_id(conn))
    conn |> OpenAIAdsCookie.delete() |> send_resp(204, "")
  end

  defp user_id(%{assigns: %{current_scope: nil}}), do: nil
  defp user_id(conn), do: conn.assigns.current_scope.user.id
end
