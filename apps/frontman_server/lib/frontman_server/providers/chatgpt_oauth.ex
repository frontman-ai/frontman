defmodule FrontmanServer.Providers.ChatGPTOAuth do
  @moduledoc """
  Handles OAuth authentication for ChatGPT Pro/Plus subscriptions.

  Implements the PKCE OAuth flow against OpenAI's auth server:
  1. Generate PKCE challenge and build authorization URL
  2. User authenticates at auth.openai.com
  3. Exchange code for access/refresh/id tokens
  4. Extract chatgpt_account_id from JWT claims
  5. Refresh tokens when expired

  Uses the same public OAuth client_id as Codex CLI and OpenCode.
  Differentiates via the `originator=frontman` parameter.
  """

  require Logger

  alias FrontmanServer.Providers.OAuthHelpers

  @client_id "app_EMoamEEZ73f0CkXaXp7hrann"
  @issuer "https://auth.openai.com"
  @auth_url "#{@issuer}/oauth/authorize"
  @token_url "#{@issuer}/oauth/token"
  @scopes "openid profile email offline_access"
  @originator "frontman"

  @doc """
  Returns the OAuth client_id.
  """
  def client_id, do: @client_id

  @doc """
  Generates a PKCE verifier and challenge. Delegates to shared helper.
  """
  @spec generate_pkce() :: {String.t(), String.t()}
  defdelegate generate_pkce(), to: OAuthHelpers

  @doc """
  Builds the authorization URL for the user to visit.

  The `redirect_uri` should be the server-side callback URL
  (e.g., "https://frontman.example.com/api/oauth/chatgpt/callback").
  """
  @spec build_authorize_url(String.t(), String.t(), String.t()) :: String.t()
  def build_authorize_url(challenge, state, redirect_uri) do
    params =
      URI.encode_query(%{
        "response_type" => "code",
        "client_id" => @client_id,
        "redirect_uri" => redirect_uri,
        "scope" => @scopes,
        "code_challenge" => challenge,
        "code_challenge_method" => "S256",
        "id_token_add_organizations" => "true",
        "codex_cli_simplified_flow" => "true",
        "state" => state,
        "originator" => @originator
      })

    "#{@auth_url}?#{params}"
  end

  @doc """
  Exchanges an authorization code for access, refresh, and id tokens.

  Note: OpenAI uses `application/x-www-form-urlencoded` (not JSON).

  Returns `{:ok, %{access_token: ..., refresh_token: ..., id_token: ..., expires_in: ...}}`
  or `{:error, reason}`.
  """
  @spec exchange_code(String.t(), String.t(), String.t()) ::
          {:ok,
           %{
             access_token: String.t(),
             refresh_token: String.t(),
             id_token: String.t(),
             expires_in: integer() | nil
           }}
          | {:error, term()}
  def exchange_code(code, verifier, redirect_uri) do
    body =
      URI.encode_query(%{
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => redirect_uri,
        "client_id" => @client_id,
        "code_verifier" => verifier
      })

    headers = [
      {"content-type", "application/x-www-form-urlencoded"},
      {"accept", "application/json"}
    ]

    case Req.post(@token_url, body: body, headers: headers) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok,
         %{
           access_token: response_body["access_token"],
           refresh_token: response_body["refresh_token"],
           id_token: response_body["id_token"],
           expires_in: response_body["expires_in"]
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "ChatGPT OAuth token exchange failed: status=#{status}, body=#{inspect(body)}"
        )

        {:error, {:token_exchange_failed, status, body}}

      {:error, reason} ->
        Logger.error("ChatGPT OAuth token exchange request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Refreshes an access token using the refresh token.

  Returns `{:ok, %{access_token: ..., refresh_token: ..., id_token: ..., expires_in: ...}}`
  or `{:error, reason}`.
  """
  @spec refresh_token(String.t()) ::
          {:ok,
           %{
             access_token: String.t(),
             refresh_token: String.t() | nil,
             id_token: String.t() | nil,
             expires_in: integer() | nil
           }}
          | {:error, term()}
  def refresh_token(refresh_token) do
    body =
      URI.encode_query(%{
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token,
        "client_id" => @client_id
      })

    headers = [
      {"content-type", "application/x-www-form-urlencoded"},
      {"accept", "application/json"}
    ]

    case Req.post(@token_url, body: body, headers: headers) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok,
         %{
           access_token: response_body["access_token"],
           refresh_token: response_body["refresh_token"],
           id_token: response_body["id_token"],
           expires_in: response_body["expires_in"]
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "ChatGPT OAuth token refresh failed: status=#{status}, body=#{inspect(body)}"
        )

        {:error, {:token_refresh_failed, status, body}}

      {:error, reason} ->
        Logger.error("ChatGPT OAuth token refresh request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Calculates the expiration DateTime from expires_in seconds.
  Delegates to shared helper.
  """
  @spec calculate_expires_at(integer()) :: DateTime.t()
  defdelegate calculate_expires_at(expires_in), to: OAuthHelpers

  @doc """
  Extracts the chatgpt_account_id from a JWT token (id_token or access_token).

  Parses the JWT payload and looks for the account ID in these locations:
  1. `https://api.openai.com/auth` -> `chatgpt_account_id`
  2. Top-level `chatgpt_account_id`
  3. First organization ID from `organizations` array

  Returns `{:ok, account_id}` or `{:error, :not_found}`.
  """
  @spec extract_account_id(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def extract_account_id(jwt) when is_binary(jwt) do
    case decode_jwt_payload(jwt) do
      {:ok, claims} ->
        account_id =
          get_in(claims, ["https://api.openai.com/auth", "chatgpt_account_id"]) ||
            claims["chatgpt_account_id"] ||
            get_first_org_id(claims)

        case account_id do
          id when is_binary(id) and id != "" -> {:ok, id}
          _ -> {:error, :not_found}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  def extract_account_id(_), do: {:error, :not_found}

  @doc """
  Extracts the account ID from token response, trying id_token first, then access_token.
  """
  @spec extract_account_id_from_tokens(%{id_token: String.t() | nil, access_token: String.t()}) ::
          String.t() | nil
  def extract_account_id_from_tokens(%{id_token: id_token, access_token: access_token}) do
    case extract_account_id(id_token) do
      {:ok, id} ->
        id

      {:error, _} ->
        case extract_account_id(access_token) do
          {:ok, id} -> id
          {:error, _} -> nil
        end
    end
  end

  # Private helpers

  defp decode_jwt_payload(jwt) do
    case String.split(jwt, ".") do
      [_header, payload, _signature] ->
        # Add padding if necessary for base64url decoding
        padded = pad_base64url(payload)

        case Base.url_decode64(padded, padding: false) do
          {:ok, json} -> Jason.decode(json)
          :error -> {:error, :invalid_base64}
        end

      _ ->
        {:error, :invalid_jwt}
    end
  end

  defp pad_base64url(str) do
    case rem(String.length(str), 4) do
      2 -> str <> "=="
      3 -> str <> "="
      _ -> str
    end
  end

  defp get_first_org_id(%{"organizations" => [%{"id" => id} | _]}) when is_binary(id), do: id
  defp get_first_org_id(_), do: nil
end
