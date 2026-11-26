defmodule FrontmanServerWeb.ConnectHandoffController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Billing
  alias FrontmanServer.WordPress
  alias FrontmanServerWeb.{Analytics, ConnectHandoff, UserAuth}

  plug(ConnectHandoff)

  def create(conn, %{"external_auth_id" => id})
      when is_binary(id) and byte_size(id) > 0 and byte_size(id) <= 512 do
    ref = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
    attempt_id = Ecto.UUID.generate()

    pending = %{
      "external_auth_id" => id,
      "ref" => ref,
      "onboarding_attempt_id" => attempt_id,
      "started_at" => System.system_time(:second),
      "user_id" => conn.assigns.current_scope && conn.assigns.current_scope.user.id
    }

    path = ~p"/auth/mcp/workos/pending?#{%{ref: ref}}"

    conn =
      conn
      |> put_session(:connect_handoff, pending)
      |> put_session(:onboarding_attempt_id, attempt_id)
      |> delete_session(:mcp_access_status)
      |> track("mcp_connection_started")

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
        status = Billing.subscription_access(conn.assigns.current_scope)

        conn
        |> track_access(status)
        |> render_checkpoint(ref, status)

      :error ->
        send_resp(conn, 400, "Invalid or expired request")
    end
  end

  def show(conn, _params), do: send_resp(conn, 400, "Invalid request")

  def complete(conn, %{"ref" => ref}) do
    case pending(conn, ref) do
      {:ok, pending} ->
        status = Billing.subscription_access(conn.assigns.current_scope)
        conn = conn |> track("mcp_authorization_submitted") |> track_access(status)

        case status do
          {:allowed, _status} ->
            conn |> delete_session(:connect_handoff) |> complete_pending(pending)

          status ->
            conn
            |> track("mcp_authorization_failed", %{reason_code: "access_denied"})
            |> put_status(:forbidden)
            |> render_checkpoint(ref, status)
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
        |> track("mcp_account_switch_requested")
        |> UserAuth.end_user_session()
        |> put_session(:connect_handoff, Map.put(pending, "user_id", nil))
        |> put_session(:onboarding_attempt_id, pending["onboarding_attempt_id"])
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
      site_links: WordPress.list_site_links(conn.assigns.current_scope),
      page_title: "Confirm your Frontman account"
    )
  end

  defp billing_status({:allowed, status}), do: status
  defp billing_status(:none), do: "none"
  defp billing_status({:inactive, status}), do: status

  defp track_access(conn, status) do
    previous = get_session(conn, :mcp_access_status)
    access = if match?({:allowed, _}, status), do: "allowed", else: "blocked"
    event = if previous, do: "mcp_access_rechecked", else: "mcp_access_evaluated"

    conn
    |> track(event, %{
      access_status: access,
      previous_access_status: previous,
      subscription_status: billing_status(status)
    })
    |> put_session(:mcp_access_status, access)
  end

  defp track(conn, event, properties \\ %{}) do
    Analytics.track(
      conn,
      event,
      Map.merge(properties, %{entry_surface: "mcp", mcp_client: "unknown"})
    )
  end

  defp complete_pending(conn, pending) do
    with {:ok, url} <-
           FrontmanServer.Accounts.complete_oauth2(
             conn.assigns.current_scope,
             pending["external_auth_id"]
           ),
         true <- FrontmanServerWeb.MCP.trusted_redirect?(url) do
      conn
      |> track("mcp_authorization_completed")
      |> redirect(external: url)
    else
      _ ->
        conn
        |> track("mcp_authorization_failed", %{reason_code: "authorization_failed"})
        |> send_resp(400, "Authorization could not continue")
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
