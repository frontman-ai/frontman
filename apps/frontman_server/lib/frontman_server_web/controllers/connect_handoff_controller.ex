defmodule FrontmanServerWeb.ConnectHandoffController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Billing
  alias FrontmanServerWeb.{ConnectHandoff, UserAuth}

  def create(conn, %{"external_auth_id" => id})
      when is_binary(id) and byte_size(id) > 0 and byte_size(id) <= 512 do
    ref = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

    pending = %{
      "external_auth_id" => id,
      "ref" => ref,
      "started_at" => System.system_time(:second),
      "user_id" => conn.assigns.current_scope && conn.assigns.current_scope.user.id
    }

    path = ~p"/auth/mcp/workos/pending?#{%{ref: ref}}"
    conn = put_session(conn, :connect_handoff, pending)

    if conn.assigns.current_scope do
      redirect(conn, to: path)
    else
      conn |> put_session(:user_return_to, path) |> redirect(to: ~p"/users/log-in")
    end
  end

  def create(conn, _params), do: send_resp(conn, 400, "Invalid request")

  def show(conn, %{"ref" => ref}) do
    case pending(conn, ref) do
      {:ok, _pending} ->
        render_checkpoint(conn, ref, Billing.subscription_access(conn.assigns.current_scope))

      :error ->
        send_resp(conn, 400, "Invalid or expired request")
    end
  end

  def show(conn, _params), do: send_resp(conn, 400, "Invalid request")

  def complete(conn, %{"ref" => ref}) do
    case pending(conn, ref) do
      {:ok, pending} ->
        case Billing.subscription_access(conn.assigns.current_scope) do
          {:allowed, _status} ->
            conn |> delete_session(:connect_handoff) |> complete_pending(pending)

          status ->
            conn |> put_status(:forbidden) |> render_checkpoint(ref, status)
        end

      :error ->
        send_resp(conn, 400, "Invalid or expired request")
    end
  end

  def complete(conn, _params), do: send_resp(conn, 400, "Invalid request")

  def switch_account(conn, %{"ref" => ref}) do
    case pending(conn, ref) do
      {:ok, pending} ->
        conn
        |> UserAuth.end_user_session()
        |> put_session(:connect_handoff, Map.put(pending, "user_id", nil))
        |> put_session(:user_return_to, ~p"/auth/mcp/workos/pending?#{%{ref: ref}}")
        |> redirect(to: ~p"/users/log-in")

      :error ->
        send_resp(conn, 400, "Invalid or expired request")
    end
  end

  def switch_account(conn, _params), do: send_resp(conn, 400, "Invalid request")

  defp render_checkpoint(conn, ref, status) do
    render(conn, :show,
      form: Phoenix.Component.to_form(%{"ref" => ref}),
      access_status: status,
      billing_status: billing_status(status),
      site_links: [],
      page_title: "Confirm your Frontman account"
    )
  end

  defp billing_status({:allowed, status}), do: status
  defp billing_status(:none), do: "none"
  defp billing_status({:inactive, status}), do: status

  defp complete_pending(conn, pending) do
    with {:ok, url} <-
           FrontmanServer.Accounts.complete_oauth2(
             conn.assigns.current_scope,
             pending["external_auth_id"]
           ),
         true <- FrontmanServerWeb.MCP.trusted_redirect?(url) do
      redirect(conn, external: url)
    else
      _ -> send_resp(conn, 400, "Authorization could not continue")
    end
  end

  defp pending(conn, ref) do
    case ConnectHandoff.pending(conn) do
      {:ok, %{"user_id" => user_id, "ref" => ^ref} = pending} when is_binary(user_id) ->
        {:ok, pending}

      _ ->
        :error
    end
  end
end
