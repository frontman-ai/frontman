defmodule FrontmanServerWeb.ConnectHandoff do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = observe_expiration(conn)

    assistant_connection =
      case conn.assigns[:embedded_request] do
        nil -> match?({:ok, _}, pending(conn))
        _request -> false
      end

    conn = assign(conn, :assistant_connection, assistant_connection)

    case assistant_connection do
      true ->
        conn
        |> put_resp_header("cache-control", "no-store")
        |> put_resp_header("referrer-policy", "no-referrer")

      false ->
        conn
    end
  end

  def pending(conn) do
    user_id = conn.assigns.current_scope && conn.assigns.current_scope.user.id

    case get_session(conn, :connect_handoff) do
      %{"user_id" => ^user_id, "ref" => ref, "started_at" => started_at} = pending
      when is_binary(ref) and is_integer(started_at) ->
        age = System.system_time(:second) - started_at
        if age >= 0 and age <= 900, do: {:ok, pending}, else: :error

      _ ->
        :error
    end
  end

  # Expiration is observable only when the browser returns, not when it closes.
  defp observe_expiration(conn) do
    case get_session(conn, :connect_handoff) do
      %{"started_at" => started_at} when is_integer(started_at) ->
        if System.system_time(:second) - started_at > 900 do
          conn
          |> FrontmanServerWeb.Analytics.track("mcp_connection_expired", %{
            entry_surface: "mcp",
            mcp_client: "unknown",
            reason_code: "handoff_expired"
          })
          |> delete_session(:connect_handoff)
          |> delete_session(:onboarding_attempt_id)
          |> delete_session(:mcp_access_status)
        else
          conn
        end

      _ ->
        conn
    end
  end
end
