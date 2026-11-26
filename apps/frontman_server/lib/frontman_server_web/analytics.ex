defmodule FrontmanServerWeb.Analytics do
  @moduledoc "Adds trusted request context without collecting URLs or request payloads."

  alias FrontmanServer.Analytics
  alias FrontmanServerWeb.Endpoint

  @receipt_salt "hosted-page-view"
  @receipt_max_age 900

  def start_attempt(conn) do
    case token_context(conn) do
      %{onboarding_attempt_id: _attempt} ->
        conn

      %{} ->
        conn
        |> Plug.Conn.delete_session(:connect_handoff)
        |> Plug.Conn.delete_session(:mcp_access_status)
        |> Plug.Conn.put_session(:onboarding_attempt_id, Ecto.UUID.generate())
        |> Plug.Conn.put_session(:onboarding_attempt_started_at, System.system_time(:second))
    end
  end

  @doc "Returns only a recent server-created authentication attempt for token issuance."
  def token_context(conn) do
    with {:ok, attempt} <- Ecto.UUID.cast(attempt_id(conn)),
         started_at when is_integer(started_at) <- attempt_started_at(conn),
         age = System.system_time(:second) - started_at,
         true <- age >= 0,
         true <- age <= 900 do
      %{onboarding_attempt_id: attempt}
    else
      _ -> %{}
    end
  end

  defp attempt_started_at(conn) do
    case Plug.Conn.get_session(conn, :connect_handoff) do
      nil ->
        Plug.Conn.get_session(conn, :onboarding_attempt_started_at)

      _handoff ->
        attempt = attempt_id(conn)

        case FrontmanServerWeb.ConnectHandoff.pending(conn) do
          {:ok, %{"onboarding_attempt_id" => ^attempt} = pending} -> pending["started_at"]
          _ -> nil
        end
    end
  end

  def track(conn, event, properties \\ %{}) do
    Analytics.track(event, Map.merge(context(conn), properties))
    conn
  end

  def page_view_receipt(conn, event, properties \\ %{}) do
    true = Analytics.browser_event?(event)

    if collection_enabled?(conn) do
      Phoenix.Token.sign(Endpoint, @receipt_salt, %{
        event: event,
        properties:
          Map.merge(context(conn), properties) |> Map.put(:event_id, Ecto.UUID.generate())
      })
    end
  end

  def record_page_view(conn, receipt) when is_binary(receipt) and byte_size(receipt) <= 4096 do
    with {:ok, %{event: event, properties: properties}} <-
           Phoenix.Token.verify(Endpoint, @receipt_salt, receipt, max_age: @receipt_max_age),
         true <- Analytics.browser_event?(event),
         {:ok, attempt} <- Ecto.UUID.cast(attempt_id(conn)),
         true <- properties.onboarding_attempt_id == attempt,
         true <- properties.user_id == user_id(conn) do
      Analytics.track(event, properties)
      :ok
    else
      _ -> {:error, :invalid_receipt}
    end
  end

  def record_page_view(_conn, _receipt), do: {:error, :invalid_receipt}

  defp context(conn) do
    %{
      request_id: request_id(conn),
      onboarding_attempt_id: event_attempt_id(conn),
      user_id: user_id(conn),
      entry_surface: entry_surface(conn),
      framework: signup_framework(conn)
    }
  end

  defp collection_enabled?(conn) do
    with true <- Analytics.config()[:enabled] == true,
         true <- identity_enabled?(user_id(conn)) do
      true
    else
      _ -> false
    end
  end

  defp identity_enabled?(nil), do: Analytics.config()[:anonymous_enabled] == true
  defp identity_enabled?(user_id) when is_binary(user_id), do: true

  # Plug.RequestId may echo a caller-controlled header; emit only an opaque keyed digest.
  defp request_id(conn) do
    case conn |> Plug.Conn.get_resp_header("x-request-id") |> List.first() do
      nil ->
        nil

      id ->
        :crypto.mac(:hmac, :sha256, Endpoint.config(:secret_key_base), id)
        |> Base.url_encode64(padding: false)
    end
  end

  defp user_id(%{assigns: %{current_scope: %{user: %{id: id}}}}), do: id
  defp user_id(_conn), do: nil

  defp attempt_id(%{private: %{plug_session: session}}),
    do: Map.get(session, "onboarding_attempt_id")

  defp attempt_id(_conn), do: nil

  # A bearer request's browser cookie may belong to another account or attempt.
  defp event_attempt_id(%{assigns: %{embedded_client_token_id: token_id} = assigns})
       when is_binary(token_id) do
    assigns |> Map.fetch!(:embedded_client_context) |> Map.get(:onboarding_attempt_id)
  end

  defp event_attempt_id(conn), do: attempt_id(conn)

  defp entry_surface(%{assigns: %{embedded_client_token_id: token_id}})
       when is_binary(token_id),
       do: "editor"

  defp entry_surface(%{assigns: %{embedded_request: request}}) when is_map(request),
    do: "editor"

  defp entry_surface(%{private: %{plug_session: %{"connect_handoff" => handoff}}})
       when is_map(handoff),
       do: "mcp"

  defp entry_surface(_conn), do: "hosted"

  defp signup_framework(%{private: %{plug_session: %{"signup_framework" => framework}}})
       when is_binary(framework) do
    if FrontmanServer.Frameworks.valid_signup_id?(framework), do: framework
  end

  defp signup_framework(_conn), do: nil
end
