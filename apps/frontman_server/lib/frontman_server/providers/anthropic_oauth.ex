# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.AnthropicOAuth do
  @moduledoc """
  Handles OAuth authentication for Anthropic Claude Pro/Max subscriptions.

  Implements the PKCE OAuth flow:
  1. Generate PKCE challenge and build authorization URL
  2. User authenticates and receives authorization code
  3. Exchange code for access/refresh tokens
  4. Refresh tokens when expired
  """

  require Logger

  @client_id Application.compile_env!(:frontman_server, [__MODULE__, :client_id])
  @auth_url Application.compile_env!(:frontman_server, [__MODULE__, :auth_url])
  @token_url Application.compile_env!(:frontman_server, [__MODULE__, :token_url])
  @redirect_uri Application.compile_env!(:frontman_server, [__MODULE__, :redirect_uri])
  @scopes Application.compile_env!(:frontman_server, [__MODULE__, :scopes])
  @req_options Application.compile_env(:frontman_server, [__MODULE__, :req_options], [])

  @doc """
  Generates a PKCE verifier and challenge.

  Returns `{verifier, challenge}` where:
  - verifier: Random 32-byte string, base64url encoded (no padding)
  - challenge: SHA-256 hash of verifier, base64url encoded (no padding)
  """
  def generate_pkce do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  @doc """
  Builds the authorization URL for the user to visit.

  The verifier should be stored and passed to `exchange_code/2` later.
  The verifier is also used as the `state` parameter in the OAuth flow.
  """
  def build_authorize_url(challenge, verifier) do
    # Use the verifier as the state parameter (as per Anthropic's OAuth flow)
    params =
      URI.encode_query(%{
        "code" => "true",
        "client_id" => @client_id,
        "response_type" => "code",
        "redirect_uri" => @redirect_uri,
        "scope" => @scopes,
        "code_challenge" => challenge,
        "code_challenge_method" => "S256",
        "state" => verifier
      })

    "#{@auth_url}?#{params}"
  end

  @doc """
  Exchanges an authorization code for access and refresh tokens.

  The code may contain a state part separated by `#`:
  - `code_part#state_part` or just `code_part`

  Returns `{:ok, %{access_token: ..., refresh_token: ..., expires_in: ...}}` or `{:error, reason}`.
  """
  def exchange_code(code_with_state, verifier) do
    # Split code on # to separate code and state parts
    {code, state} =
      case String.split(code_with_state, "#", parts: 2) do
        [code_part, state_part] -> {code_part, state_part}
        [code_part] -> {code_part, nil}
      end

    body =
      %{
        "code" => code,
        "grant_type" => "authorization_code",
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "code_verifier" => verifier
      }
      |> add_state(state)

    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]

    case Req.post(@token_url, [json: body, headers: headers] ++ @req_options) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok,
         %{
           access_token: response_body["access_token"],
           refresh_token: response_body["refresh_token"],
           expires_in: response_body["expires_in"]
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "Anthropic OAuth token exchange failed: status=#{status}, body=#{inspect(body)}"
        )

        {:error, {:token_exchange_failed, status, body}}

      {:error, reason} ->
        Logger.error("Anthropic OAuth token exchange request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Refreshes an access token using the refresh token.

  Returns `{:ok, %{access_token: ..., refresh_token: ..., expires_in: ...}}` or `{:error, reason}`.
  """
  def refresh_token(refresh_token) do
    body = %{
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token,
      "client_id" => @client_id
    }

    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]

    case Req.post(@token_url, [json: body, headers: headers] ++ @req_options) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok,
         %{
           access_token: response_body["access_token"],
           refresh_token: response_body["refresh_token"],
           expires_in: response_body["expires_in"]
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "Anthropic OAuth token refresh failed: status=#{status}, body=#{inspect(body)}"
        )

        {:error, {:token_refresh_failed, status, body}}

      {:error, reason} ->
        Logger.error("Anthropic OAuth token refresh request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  # Private helpers

  defp add_state(body, nil), do: body
  defp add_state(body, state), do: Map.put(body, "state", state)
end
