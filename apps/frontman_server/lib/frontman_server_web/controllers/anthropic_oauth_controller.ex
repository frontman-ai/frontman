defmodule FrontmanServerWeb.AnthropicOAuthController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.AnthropicOAuth
  alias FrontmanServer.Providers.OAuthToken

  @doc """
  Generates a PKCE challenge and returns the authorization URL.

  The client should store the verifier and pass it back when exchanging the code.
  """
  def authorize_url(conn, _params) do
    {verifier, challenge} = AnthropicOAuth.generate_pkce()
    authorize_url = AnthropicOAuth.build_authorize_url(challenge, verifier)

    json(conn, %{
      authorize_url: authorize_url,
      verifier: verifier
    })
  end

  @doc """
  Exchanges an authorization code for tokens and stores them.

  Expects:
  - code: The authorization code (may contain #state_part)
  - verifier: The PKCE verifier from authorize_url
  """
  def exchange(conn, %{"code" => code, "verifier" => verifier}) do
    scope = conn.assigns.current_scope

    case AnthropicOAuth.exchange_code(code, verifier) do
      {:ok, tokens} ->
        expires_at = AnthropicOAuth.calculate_expires_at(tokens.expires_in)

        case Providers.upsert_oauth_token(
               scope,
               "anthropic",
               tokens.access_token,
               tokens.refresh_token,
               expires_at
             ) do
          {:ok, _token} ->
            json(conn, %{
              status: "ok",
              expires_at: DateTime.to_iso8601(expires_at)
            })

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{status: "error", error: translate_errors(changeset)})
        end

      {:error, {:token_exchange_failed, status, body}} ->
        error_message =
          extract_error_message(body) || "Token exchange failed with status #{status}"

        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", error: error_message})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", error: "Failed to exchange code: #{inspect(reason)}"})
    end
  end

  def exchange(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", error: "Missing required parameters: code, verifier"})
  end

  @doc """
  Disconnects the Anthropic OAuth connection by removing stored tokens.
  """
  def disconnect(conn, _params) do
    scope = conn.assigns.current_scope

    case Providers.delete_oauth_token(scope, "anthropic") do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        # Token didn't exist, but that's fine - user is disconnected either way
        json(conn, %{status: "ok"})
    end
  end

  @doc """
  Returns the current OAuth connection status.
  """
  def status(conn, _params) do
    scope = conn.assigns.current_scope

    case Providers.get_oauth_token(scope, "anthropic") do
      nil ->
        json(conn, %{
          connected: false
        })

      token ->
        json(conn, %{
          connected: true,
          expires_at: DateTime.to_iso8601(token.expires_at),
          expired: OAuthToken.expired?(token)
        })
    end
  end

  # Private helpers

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end

  defp extract_error_message(%{"error" => %{"message" => message}}), do: message
  defp extract_error_message(%{"error_description" => desc}), do: desc
  defp extract_error_message(%{"error" => error}) when is_binary(error), do: error
  defp extract_error_message(_), do: nil
end
