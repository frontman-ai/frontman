# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Accounts.WorkOS do
  @moduledoc """
  Handles OAuth authentication via WorkOS for social logins (GitHub, Google).

  This module provides functions to:
  - Generate authorization URLs for OAuth providers
  - Authenticate users with OAuth codes
  - Link/unlink OAuth providers to existing accounts
  - Handle email verification for providers that don't auto-verify
  """

  alias Ecto.Multi
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Accounts.UserIdentity
  alias FrontmanServer.Accounts.WorkOS.AuthError
  alias FrontmanServer.Repo
  alias FrontmanServer.Workers.NotifyDiscordNewUser
  alias FrontmanServer.Workers.SendWelcomeEmail
  alias FrontmanServer.Workers.SyncResendContact

  import Ecto.Changeset
  import Ecto.Query

  require Logger

  @supported_providers ~w(github google)
  @http_timeout_ms 15_000
  @workos_api_base "https://api.workos.com"

  @doc """
  Generates a WorkOS authorization URL for the given provider.

  ## Examples

      iex> get_authorization_url("github", "http://localhost:4000/auth/github/callback")
      {:ok, "https://api.workos.com/..."}

  """
  @spec get_authorization_url(String.t(), String.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def get_authorization_url(provider, redirect_uri, state \\ nil)

  def get_authorization_url(provider, redirect_uri, state)
      when provider in @supported_providers do
    opts =
      %{
        provider: provider_to_workos(provider),
        redirect_uri: redirect_uri,
        state: state
      }
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

    WorkOS.UserManagement.get_authorization_url(opts)
  end

  def get_authorization_url(provider, _redirect_uri, _state) do
    {:error,
     "Unsupported provider: #{provider}. Supported: #{Enum.join(@supported_providers, ", ")}"}
  end

  @doc """
  Authenticates a user with an OAuth authorization code.

  This function:
  1. Exchanges the code with WorkOS for user profile data
  2. Extracts the provider from the authentication_method in the response
  3. Checks if an identity already exists for this provider+provider_id → logs in
  4. Checks if a user exists with matching email → links identity and logs in
  5. Creates a new user + identity → logs in

  Returns `{:ok, user, oauth_tokens}` on success or `{:error, reason}` on failure.
  `oauth_tokens` is `%{provider: "github", ...}` or `nil`.

  Note: We use a raw HTTP call instead of the SDK to capture the full error
  response, including `pending_authentication_token` for email verification.
  """
  @spec authenticate_with_code(String.t()) ::
          {:ok, User.t(), map() | nil} | {:error, term()}
  def authenticate_with_code(code) do
    with {:ok, auth_response} <- authenticate_with_code_raw(code) do
      resolve_user_from_auth(auth_response)
    end
  end

  @doc """
  Completes authentication after email verification.

  Used when the initial OAuth returns `email_verification_required`. The user
  receives a verification code via email, which is then submitted along with
  the pending authentication token to complete the flow.
  """
  @spec authenticate_with_email_verification(String.t(), String.t()) ::
          {:ok, User.t(), map() | nil} | {:error, term()}
  def authenticate_with_email_verification(code, pending_authentication_token) do
    body = %{
      client_id: workos_client_id(),
      client_secret: workos_api_key(),
      grant_type: "urn:workos:oauth:grant-type:email-verification:code",
      code: code,
      pending_authentication_token: pending_authentication_token
    }

    opts = [json: body, receive_timeout: @http_timeout_ms] ++ workos_req_options()

    case Req.post("#{@workos_api_base}/user_management/authenticate", opts) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        with {:ok, auth_response} <- parse_auth_response(response_body) do
          resolve_user_from_auth(auth_response)
        end

      {:ok, %Req.Response{status: status, body: error_body}} ->
        Logger.debug(
          "WorkOS email verify error - status: #{status}, body: #{inspect(error_body)}"
        )

        {:error, AuthError.from_response(error_body)}

      {:error, reason} ->
        Logger.error("WorkOS email verify request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Links an OAuth provider to an existing user account.

  Returns `{:ok, identity}` on success or `{:error, changeset}` on failure.
  """
  @spec link_provider(User.t(), String.t()) :: {:ok, UserIdentity.t()} | {:error, term()}
  def link_provider(user, code) do
    with {:ok, auth_response} <- authenticate_with_code_raw(code),
         {:ok, profile} <- extract_profile(auth_response) do
      create_identity(user, profile)
    end
  end

  @doc """
  Unlinks an OAuth provider from a user account.

  Returns `{:ok, identity}` on success or `{:error, :not_found}` if the identity doesn't exist.
  """
  @spec unlink_provider(User.t(), String.t()) ::
          {:ok, UserIdentity.t()} | {:error, :not_found | String.t()}
  def unlink_provider(user, provider) when provider in @supported_providers do
    case get_identity_by_provider(user, provider) do
      nil -> {:error, :not_found}
      identity -> Repo.delete(identity)
    end
  end

  def unlink_provider(_user, provider) do
    {:error, "Unsupported provider: #{provider}"}
  end

  @doc """
  Lists all OAuth identities for a user.
  """
  @spec list_identities(User.t()) :: [UserIdentity.t()]
  def list_identities(user) do
    UserIdentity
    |> where([i], i.user_id == ^user.id)
    |> Repo.all()
  end

  @doc """
  Gets a specific identity by provider for a user.
  """
  @spec get_identity_by_provider(User.t(), String.t()) :: UserIdentity.t() | nil
  def get_identity_by_provider(user, provider) do
    UserIdentity
    |> where([i], i.user_id == ^user.id and i.provider == ^provider)
    |> Repo.one()
  end

  @doc """
  Extracts provider OAuth tokens from the raw WorkOS authentication response body.

  Returns a plain map of token fields when present, or `nil` when absent.
  """
  @spec extract_oauth_tokens(map()) :: map() | nil
  def extract_oauth_tokens(%{"oauth_tokens" => %{"access_token" => _} = tokens}) do
    %{
      access_token: tokens["access_token"],
      refresh_token: tokens["refresh_token"],
      expires_at: tokens["expires_at"],
      scopes: tokens["scopes"]
    }
  end

  def extract_oauth_tokens(_body), do: nil

  # Private functions

  defp resolve_user_from_auth(auth_response) do
    with {:ok, profile} <- extract_profile(auth_response) do
      case find_or_create_user_from_oauth(profile) do
        {:ok, user} ->
          {:ok, user, build_oauth_tokens(profile.provider, auth_response[:oauth_tokens])}

        {:error, _} = error ->
          error
      end
    end
  end

  defp build_oauth_tokens(provider, %{} = tokens), do: Map.put(tokens, :provider, provider)
  defp build_oauth_tokens(_provider, nil), do: nil

  defp extract_profile(%{user: user, authentication_method: auth_method}) do
    provider = workos_to_provider(auth_method)

    {:ok,
     %{
       provider: provider,
       provider_id: user[:id],
       provider_email: user[:email],
       provider_name: extract_name(user),
       provider_avatar_url: user[:profile_picture_url]
     }}
  end

  defp workos_to_provider("GitHubOAuth"), do: "github"
  defp workos_to_provider("GoogleOAuth"), do: "google"

  defp extract_name(%{first_name: first, last_name: last})
       when is_binary(first) and is_binary(last),
       do: "#{first} #{last}"

  defp extract_name(%{first_name: first}) when is_binary(first), do: first
  defp extract_name(%{last_name: last}) when is_binary(last), do: last

  defp extract_name(%{email: email}) when is_binary(email),
    do: email |> String.split("@") |> List.first()

  defp extract_name(_user), do: "Unknown"

  defp find_or_create_user_from_oauth(profile) do
    identity = get_identity_by_provider_id(profile.provider, profile.provider_id)
    existing_user = get_user_by_email(profile.provider_email)

    multi = build_oauth_multi(identity, existing_user, profile)

    case Repo.transaction(multi) do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  # Suppress Dialyzer false positive: Ecto.Multi.new/0 returns a struct with
  # opaque MapSet internals that Dialyzer flags as call_without_opaque.
  @dialyzer {:nowarn_function, build_oauth_multi: 3}

  # Returning user with existing identity — touch timestamps, no welcome email.
  defp build_oauth_multi(%UserIdentity{} = identity, _existing_user, _profile) do
    now = DateTime.utc_now(:second)

    Multi.new()
    |> Multi.update(:identity, UserIdentity.touch_changeset(identity))
    |> Multi.update(
      :user,
      User |> Repo.get!(identity.user_id) |> change(last_signed_in_at: now)
    )
  end

  # Existing user by email but no identity for this provider — link identity.
  defp build_oauth_multi(nil, %User{} = user, profile) do
    now = DateTime.utc_now(:second)

    Multi.new()
    |> Multi.insert(:identity, build_identity_changeset(user, profile))
    |> Multi.update(:user, change(user, last_signed_in_at: now))
  end

  # Brand-new user — create user + identity + enqueue welcome email.
  defp build_oauth_multi(nil, nil, profile) do
    Multi.new()
    |> Multi.insert(
      :user,
      User.oauth_registration_changeset(%User{}, %{
        email: profile.provider_email,
        name: profile.provider_name
      })
    )
    |> Multi.insert(:identity, fn %{user: user} ->
      build_identity_changeset(user, profile)
    end)
    |> Oban.insert(:welcome_email, fn %{user: user} ->
      SendWelcomeEmail.new(%{user_id: user.id})
    end)
    |> Oban.insert(:sync_resend_contact, fn %{user: user} ->
      SyncResendContact.new(%{user_id: user.id})
    end)
    |> Oban.insert(:notify_discord, fn %{user: user} ->
      NotifyDiscordNewUser.new(%{user_id: user.id})
    end)
  end

  defp build_identity_changeset(user, profile) do
    %UserIdentity{user_id: user.id}
    |> UserIdentity.changeset(%{
      provider: profile.provider,
      provider_id: profile.provider_id,
      provider_email: profile.provider_email,
      provider_name: profile.provider_name,
      provider_avatar_url: profile.provider_avatar_url
    })
    |> put_change(:last_signed_in_at, DateTime.utc_now(:second))
  end

  defp get_identity_by_provider_id(provider, provider_id) do
    UserIdentity
    |> where([i], i.provider == ^provider and i.provider_id == ^provider_id)
    |> Repo.one()
  end

  defp get_user_by_email(email) when email in [nil, ""], do: nil

  defp get_user_by_email(email) when is_binary(email) do
    User
    |> where([u], u.email == ^email)
    |> Repo.one()
  end

  defp create_identity(user, profile) do
    build_identity_changeset(user, profile)
    |> Repo.insert()
  end

  defp provider_to_workos("github"), do: "GitHubOAuth"
  defp provider_to_workos("google"), do: "GoogleOAuth"

  # Raw HTTP authentication to capture full error responses

  defp authenticate_with_code_raw(code) do
    body = %{
      client_id: workos_client_id(),
      client_secret: workos_api_key(),
      grant_type: "authorization_code",
      code: code
    }

    opts = [json: body, receive_timeout: @http_timeout_ms] ++ workos_req_options()

    case Req.post("#{@workos_api_base}/user_management/authenticate", opts) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        parse_auth_response(response_body)

      {:ok, %Req.Response{status: status, body: error_body}} ->
        Logger.debug("WorkOS auth error - status: #{status}, body: #{inspect(error_body)}")
        {:error, AuthError.from_response(error_body)}

      {:error, reason} ->
        Logger.error("WorkOS request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_auth_response(%{"user" => %{} = user_data} = body) do
    user = %{
      id: user_data["id"],
      email: user_data["email"],
      email_verified: user_data["email_verified"],
      first_name: user_data["first_name"],
      last_name: user_data["last_name"],
      profile_picture_url: user_data["profile_picture_url"],
      created_at: user_data["created_at"],
      updated_at: user_data["updated_at"]
    }

    {:ok,
     %{
       user: user,
       access_token: body["access_token"],
       refresh_token: body["refresh_token"],
       authentication_method: body["authentication_method"],
       oauth_tokens: extract_oauth_tokens(body)
     }}
  end

  defp parse_auth_response(_body) do
    {:error,
     %AuthError{code: "invalid_response", message: "Missing user data in authentication response"}}
  end

  defp workos_api_key do
    Application.get_env(:workos, WorkOS.Client)[:api_key]
  end

  defp workos_client_id do
    Application.get_env(:workos, WorkOS.Client)[:client_id]
  end

  defp workos_req_options do
    Application.get_env(:frontman_server, :workos_req_options, [])
  end
end
