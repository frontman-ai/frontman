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

  @supported_providers ~w(github google)
  @workos_api_base "https://api.workos.com"
  @workos_auth_max_attempts 2
  @workos_auth_connect_timeout_ms 5_000
  @workos_auth_receive_timeout_ms 30_000

  @type signup_framework :: String.t() | nil

  @doc """
  Generates a WorkOS authorization URL for the given provider.

  ## Examples

      iex> get_authorization_url("github", "http://localhost:4000/auth/github/callback")
      {:ok, "https://api.workos.com/..."}

  """
  @spec get_authorization_url(String.t(), String.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, term()}
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

  Returns `{:ok, user}` on success or `{:error, reason}` on failure.

  Note: We use a raw HTTP call instead of the SDK to capture the full error
  response, including `pending_authentication_token` for email verification.
  """
  @spec authenticate_with_code(String.t(), signup_framework()) ::
          {:ok, User.t()} | {:error, term()}
  def authenticate_with_code(code, signup_framework \\ nil)

  def authenticate_with_code(code, nil) when is_binary(code) and code != "" do
    authenticate_with_code_internal(code, nil)
  end

  def authenticate_with_code(code, signup_framework)
      when is_binary(code) and code != "" and is_binary(signup_framework) do
    authenticate_with_code_internal(code, signup_framework)
  end

  def authenticate_with_code("", _signup_framework), do: {:error, {:invalid_argument, :code}}

  def authenticate_with_code(code, _signup_framework) when not is_binary(code),
    do: {:error, {:invalid_argument, :code}}

  def authenticate_with_code(_code, _signup_framework),
    do: {:error, {:invalid_argument, :signup_framework}}

  defp authenticate_with_code_internal(code, signup_framework) do
    with {:ok, auth_response} <- authenticate_with_code_raw(code),
         {:ok, profile} <- extract_profile(auth_response) do
      find_or_create_user_from_oauth(profile, signup_framework)
    end
  end

  @doc """
  Completes authentication after email verification.

  Used when the initial OAuth returns `email_verification_required`. The user
  receives a verification code via email, which is then submitted along with
  the pending authentication token to complete the flow.
  """
  @spec authenticate_with_email_verification(String.t(), String.t(), signup_framework()) ::
          {:ok, User.t()} | {:error, term()}
  def authenticate_with_email_verification(
        code,
        pending_authentication_token,
        signup_framework \\ nil
      )

  def authenticate_with_email_verification(code, pending_authentication_token, nil)
      when is_binary(code) and code != "" and is_binary(pending_authentication_token) and
             pending_authentication_token != "" do
    authenticate_with_email_verification_internal(code, pending_authentication_token, nil)
  end

  def authenticate_with_email_verification(code, pending_authentication_token, signup_framework)
      when is_binary(code) and code != "" and is_binary(pending_authentication_token) and
             pending_authentication_token != "" and is_binary(signup_framework) do
    authenticate_with_email_verification_internal(
      code,
      pending_authentication_token,
      signup_framework
    )
  end

  def authenticate_with_email_verification("", _pending_authentication_token, _signup_framework),
    do: {:error, {:invalid_argument, :code}}

  def authenticate_with_email_verification(_code, "", _signup_framework),
    do: {:error, {:invalid_argument, :pending_authentication_token}}

  def authenticate_with_email_verification(code, _pending_authentication_token, _signup_framework)
      when not is_binary(code),
      do: {:error, {:invalid_argument, :code}}

  def authenticate_with_email_verification(_code, pending_authentication_token, _signup_framework)
      when not is_binary(pending_authentication_token),
      do: {:error, {:invalid_argument, :pending_authentication_token}}

  def authenticate_with_email_verification(
        _code,
        _pending_authentication_token,
        _signup_framework
      ),
      do: {:error, {:invalid_argument, :signup_framework}}

  defp authenticate_with_email_verification_internal(
         code,
         pending_authentication_token,
         signup_framework
       ) do
    body = %{
      client_id: workos_client_id(),
      client_secret: workos_api_key(),
      grant_type: "urn:workos:oauth:grant-type:email-verification:code",
      code: code,
      pending_authentication_token: pending_authentication_token
    }

    with {:ok, response_body} <- post_authenticate_request(body, "email verify"),
         {:ok, auth_response} <- parse_auth_response(response_body),
         {:ok, profile} <- extract_profile(auth_response) do
      find_or_create_user_from_oauth(profile, signup_framework)
    end
  end

  @doc """
  Links an OAuth provider to an existing user account.

  Returns `{:ok, identity}` on success or `{:error, changeset}` on failure.
  """
  @spec link_provider(User.t(), String.t()) :: {:ok, UserIdentity.t()} | {:error, term()}
  def link_provider(%User{} = user, code) when is_binary(code) and code != "" do
    with {:ok, auth_response} <- authenticate_with_code_raw(code),
         {:ok, profile} <- extract_profile(auth_response) do
      create_identity(user, profile)
    end
  end

  def link_provider(%User{}, ""), do: {:error, {:invalid_argument, :code}}
  def link_provider(%User{}, _code), do: {:error, {:invalid_argument, :code}}

  @doc """
  Unlinks an OAuth provider from a user account.

  Returns `{:ok, identity}` on success or `{:error, :not_found}` if the identity doesn't exist.
  """
  @spec unlink_provider(User.t(), String.t()) ::
          {:ok, UserIdentity.t()} | {:error, :not_found | String.t() | term()}
  def unlink_provider(%User{} = user, provider) when provider in @supported_providers do
    case get_identity_by_provider(user, provider) do
      nil -> {:error, :not_found}
      identity -> Repo.delete(identity)
    end
  end

  def unlink_provider(%User{}, provider) do
    {:error, "Unsupported provider: #{provider}"}
  end

  @doc """
  Lists all OAuth identities for a user.
  """
  @spec list_identities(User.t()) :: [UserIdentity.t()]
  def list_identities(%User{} = user) do
    UserIdentity
    |> where([i], i.user_id == ^user.id)
    |> Repo.all()
  end

  @doc """
  Gets a specific identity by provider for a user.
  """
  @spec get_identity_by_provider(User.t(), String.t()) :: UserIdentity.t() | nil
  def get_identity_by_provider(%User{} = user, provider) when is_binary(provider) do
    UserIdentity
    |> where([i], i.user_id == ^user.id and i.provider == ^provider)
    |> Repo.one()
  end

  # Private functions

  defp extract_profile(%{user: user, authentication_method: auth_method}) do
    with {:ok, provider} <- workos_to_provider(auth_method) do
      {:ok,
       %{
         provider: provider,
         provider_id: user[:id],
         provider_email: user[:email],
         provider_name: extract_name(user),
         provider_avatar_url: user[:profile_picture_url]
       }}
    end
  end

  defp workos_to_provider("GitHubOAuth"), do: {:ok, "github"}
  defp workos_to_provider("GoogleOAuth"), do: {:ok, "google"}

  defp workos_to_provider(authentication_method) do
    {:error, {:invalid_authentication_method, authentication_method}}
  end

  defp extract_name(user) do
    first_name = user[:first_name]
    last_name = user[:last_name]
    email = user[:email]

    case first_name do
      nil -> extract_name_from_last_name_or_email(last_name, email)
      "" -> extract_name_from_last_name_or_email(last_name, email)
      value -> extract_name_with_last_name(value, last_name)
    end
  end

  defp extract_name_with_last_name(first_name, nil), do: first_name
  defp extract_name_with_last_name(first_name, ""), do: first_name
  defp extract_name_with_last_name(first_name, last_name), do: "#{first_name} #{last_name}"

  defp extract_name_from_last_name_or_email(nil, email), do: extract_name_from_email(email)
  defp extract_name_from_last_name_or_email("", email), do: extract_name_from_email(email)
  defp extract_name_from_last_name_or_email(last_name, _email), do: last_name

  defp extract_name_from_email(nil), do: "Unknown"
  defp extract_name_from_email(""), do: "Unknown"

  defp extract_name_from_email(email) do
    email
    |> String.split("@")
    |> List.first()
  end

  defp find_or_create_user_from_oauth(profile, signup_framework) do
    identity = get_identity_by_provider_id(profile.provider, profile.provider_id)
    existing_user = get_user_by_email(profile.provider_email)

    multi = build_oauth_multi(identity, existing_user, profile, signup_framework)

    case Repo.transaction(multi) do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  # Suppress Dialyzer false positive: Ecto.Multi.new/0 returns a struct with
  # opaque MapSet internals that Dialyzer flags as call_without_opaque.
  @dialyzer {:nowarn_function, build_oauth_multi: 4}

  # Returning user with existing identity — touch timestamps, no welcome email.
  defp build_oauth_multi(%UserIdentity{} = identity, _existing_user, _profile, _signup_framework) do
    now = DateTime.utc_now(:second)

    Multi.new()
    |> Multi.update(:identity, UserIdentity.touch_changeset(identity))
    |> Multi.update(
      :user,
      User |> Repo.get!(identity.user_id) |> change(last_signed_in_at: now)
    )
  end

  # Existing user by email but no identity for this provider — link identity.
  defp build_oauth_multi(nil, %User{} = user, profile, _signup_framework) do
    now = DateTime.utc_now(:second)

    Multi.new()
    |> Multi.insert(:identity, build_identity_changeset(user, profile))
    |> Multi.update(:user, change(user, last_signed_in_at: now))
  end

  # Brand-new user — create user + identity + enqueue welcome email.
  defp build_oauth_multi(nil, nil, profile, signup_framework) do
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
      NotifyDiscordNewUser.new(notify_discord_args(user.id, signup_framework))
    end)
  end

  defp notify_discord_args(user_id, nil), do: %{user_id: user_id}
  defp notify_discord_args(user_id, framework), do: %{user_id: user_id, framework: framework}

  defp build_identity_changeset(user, profile) do
    %UserIdentity{}
    |> UserIdentity.changeset(%{
      user_id: user.id,
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

  # Raw HTTP authentication to capture full error responses.

  defp authenticate_with_code_raw(code) do
    body = %{
      client_id: workos_client_id(),
      client_secret: workos_api_key(),
      grant_type: "authorization_code",
      code: code
    }

    with {:ok, response_body} <- post_authenticate_request(body, "auth") do
      parse_auth_response(response_body)
    end
  end

  defp post_authenticate_request(body, context, attempt \\ 1) do
    require Logger

    case Req.post("#{@workos_api_base}/user_management/authenticate",
           json: body,
           receive_timeout: @workos_auth_receive_timeout_ms,
           connect_options: [timeout: @workos_auth_connect_timeout_ms]
         ) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: error_body}} ->
        Logger.debug("WorkOS #{context} error - status: #{status}, body: #{inspect(error_body)}")
        {:error, AuthError.from_response(error_body)}

      {:error, %Req.TransportError{reason: :closed}} when attempt < @workos_auth_max_attempts ->
        Logger.warning(
          "WorkOS #{context} request transport closed (attempt #{attempt}/#{@workos_auth_max_attempts}); retrying"
        )

        post_authenticate_request(body, context, attempt + 1)

      {:error, %Req.TransportError{reason: :closed} = reason} ->
        Logger.error(
          "WorkOS #{context} request failed after #{attempt} attempt(s): #{inspect(reason)}"
        )

        {:error, reason}

      {:error, reason} ->
        Logger.error("WorkOS #{context} request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_auth_response(
         %{"user" => user, "authentication_method" => authentication_method} = body
       )
       when is_map(user) do
    with {:ok, user_id} <- require_non_empty_binary(user["id"], :user_id),
         {:ok, user_email} <- require_non_empty_binary(user["email"], :user_email),
         {:ok, auth_method} <-
           require_non_empty_binary(authentication_method, :authentication_method) do
      {:ok,
       %{
         user: %{
           id: user_id,
           email: user_email,
           email_verified: user["email_verified"],
           first_name: user["first_name"],
           last_name: user["last_name"],
           profile_picture_url: user["profile_picture_url"],
           created_at: user["created_at"],
           updated_at: user["updated_at"]
         },
         access_token: body["access_token"],
         refresh_token: body["refresh_token"],
         authentication_method: auth_method
       }}
    end
  end

  defp parse_auth_response(body) do
    {:error, {:invalid_auth_response, body}}
  end

  defp require_non_empty_binary("", field), do: {:error, {:invalid_auth_response_field, field}}
  defp require_non_empty_binary(value, _field) when is_binary(value), do: {:ok, value}

  defp require_non_empty_binary(_value, field),
    do: {:error, {:invalid_auth_response_field, field}}

  defp workos_api_key do
    Application.get_env(:workos, WorkOS.Client)[:api_key]
  end

  defp workos_client_id do
    Application.get_env(:workos, WorkOS.Client)[:client_id]
  end
end
