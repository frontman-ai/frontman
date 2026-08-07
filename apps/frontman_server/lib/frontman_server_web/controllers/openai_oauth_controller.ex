defmodule FrontmanServerWeb.OpenAIOAuthController do
  use FrontmanServerWeb, :controller

  require Logger

  alias FrontmanServer.Providers

  def initiate(conn, _params) do
    case Providers.start_openai_oauth() do
      {:ok, device_auth} ->
        json(conn, device_auth)

      {:error, :device_auth_not_enabled} ->
        conn
        |> put_status(503)
        |> json(%{error: "Device auth is not currently available. Please try again later."})

      {:error, reason} ->
        Logger.error("OpenAI device code request failed: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{error: "Failed to initiate authentication. Please try again."})
    end
  end

  def poll(conn, %{"device_auth_id" => device_auth_id, "user_code" => user_code})
      when is_binary(device_auth_id) and is_binary(user_code) do
    case Providers.poll_openai_oauth(conn.assigns.current_scope, device_auth_id, user_code) do
      {:connected, expires_at} ->
        json(conn, %{
          status: "connected",
          expires_at: DateTime.to_iso8601(expires_at)
        })

      {:pending} ->
        json(conn, %{status: "pending"})

      {:error, :authorization_declined} ->
        conn
        |> put_status(403)
        |> json(%{status: "declined", error: "Authorization was declined."})

      {:exchange_error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to store OpenAI OAuth token: #{inspect(changeset)}")

        conn
        |> put_status(500)
        |> json(%{status: "error", error: "Failed to save tokens. Please try again."})

      {:exchange_error, reason} ->
        Logger.error("OpenAI device code exchange failed: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{status: "error", error: "Failed to exchange authorization code."})

      {:error, reason} ->
        Logger.error("OpenAI device poll error: #{inspect(reason)}")
        json(conn, %{status: "pending"})
    end
  end

  def poll(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameters: device_auth_id, user_code"})
  end

  def disconnect(conn, _params) do
    scope = conn.assigns.current_scope

    case Providers.delete_oauth_token(scope, "openai_codex") do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        json(conn, %{status: "ok"})
    end
  end

  def status(conn, _params) do
    json(conn, Providers.oauth_connection_status(conn.assigns.current_scope, "openai_codex"))
  end
end
