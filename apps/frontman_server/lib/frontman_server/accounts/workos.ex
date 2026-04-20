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

  @doc """
  Generates a WorkOS authorization URL for the given provider.

  ## Examples

      iex> get_authorization_url("github", "http://localhost:4000/auth/github/callback")
      {:ok, "https://api.workos.com/..."}

  """
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
  def authenticate_with_code(code, signup_framework \\ nil) do
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
  def authenticate_with_email_verification(
        code,
        pending_authentication_token,
        signup_framework \\ nil
      ) do
    require Logger

    body = %{
      client_id: workos_client_id(),
      client_secret: workos_api_key(),
      grant_type: "urn:workos:oauth:grant-type:email-verification:code",
      code: code,
      pending_authentication_token: pending_authentication_token
    }

    case Req.post("#{@workos_api_base}/user_management/authenticate", json: body) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        with {:ok, auth_response} <- parse_auth_response(response_body),
             {:ok, profile} <- extract_profile(auth_response) do
          find_or_create_user_from_oauth(profile, signup_framework)
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
  def list_identities(user) do
    UserIdentity
    |> where([i], i.user_id == ^user.id)
    |> Repo.all()
  end

  @doc """
  Gets a specific identity by provider for a user.
  """
  def get_identity_by_provider(user, provider) do
    UserIdentity
    |> where([i], i.user_id == ^user.id and i.provider == ^provider)
    |> Repo.one()
  end

  # Private functions

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

  defp extract_name(user) do
    first_name = user[:first_name]
    last_name = user[:last_name]
    email = user[:email]

    cond do
      first_name && last_name -> "#{first_name} #{last_name}"
      first_name -> first_name
      last_name -> last_name
      email -> email |> String.split("@") |> List.first()
      true -> "Unknown"
    end
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

  # Raw HTTP authentication to capture full error responses

  defp authenticate_with_code_raw(code) do
    require Logger

    body = %{
      client_id: workos_client_id(),
      client_secret: workos_api_key(),
      grant_type: "authorization_code",
      code: code
    }

    case Req.post("#{@workos_api_base}/user_management/authenticate", json: body) do
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

  defp parse_auth_response(body) do
    user = %{
      id: body["user"]["id"],
      email: body["user"]["email"],
      email_verified: body["user"]["email_verified"],
      first_name: body["user"]["first_name"],
      last_name: body["user"]["last_name"],
      profile_picture_url: body["user"]["profile_picture_url"],
      created_at: body["user"]["created_at"],
      updated_at: body["user"]["updated_at"]
    }

    {:ok,
     %{
       user: user,
       access_token: body["access_token"],
       refresh_token: body["refresh_token"],
       authentication_method: body["authentication_method"]
     }}
  end

  defp workos_api_key do
    Application.get_env(:workos, WorkOS.Client)[:api_key]
  end

  defp workos_client_id do
    Application.get_env(:workos, WorkOS.Client)[:client_id]
  end
end
