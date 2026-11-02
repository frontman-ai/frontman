defmodule FrontmanServerWeb.ConnectHandoffController do
  use FrontmanServerWeb, :controller

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
        token = Plug.CSRFProtection.get_csrf_token()

        html(conn, """
        <p>Continue connecting your account. This does not grant access to a WordPress site.</p>
        <form method="post" action="/auth/mcp/workos/pending">
          <input type="hidden" name="_csrf_token" value="#{token}">
          <input type="hidden" name="ref" value="#{ref}">
          <button type="submit">Continue</button>
        </form>
        """)

      :error ->
        send_resp(conn, 400, "Invalid or expired request")
    end
  end

  def show(conn, _params), do: send_resp(conn, 400, "Invalid request")

  def complete(conn, %{"ref" => ref}) do
    case pending(conn, ref) do
      {:ok, pending} ->
        conn = delete_session(conn, :connect_handoff)
        complete_pending(conn, pending)

      :error ->
        send_resp(conn, 400, "Invalid or expired request")
    end
  end

  def complete(conn, _params), do: send_resp(conn, 400, "Invalid request")

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
    case {conn.assigns.current_scope, get_session(conn, :connect_handoff)} do
      {%{user: %{id: user_id}},
       %{"user_id" => user_id, "ref" => ^ref, "started_at" => started_at} = pending}
      when is_integer(started_at) ->
        age = System.system_time(:second) - started_at
        if age >= 0 and age <= 900, do: {:ok, pending}, else: :error

      _ ->
        :error
    end
  end
end
