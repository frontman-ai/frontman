# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `FrontmanServer.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  use TypedStruct

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Organizations.Organization

  typedstruct do
    field :user, %User{}
    field :organization, %Organization{}
    field :env_api_keys, %{String.t() => String.t()}, default: %{}
  end

  @doc """
  Returns a scope enriched with environment-provided API keys.

  Keys set here travel with the scope to all domain functions, so callers
  don't need to pass env_api_key as a separate argument.
  """
  def with_env_api_keys(%__MODULE__{} = scope, keys) when is_map(keys) do
    %{scope | env_api_keys: keys}
  end

  def with_env_api_keys(%__MODULE__{} = scope, _), do: scope

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user, organization: nil}
  end

  def for_user(nil), do: nil

  def for_user(%User{} = user, %Organization{} = organization) do
    %__MODULE__{user: user, organization: organization}
  end

  def for_user(%User{} = user, nil) do
    %__MODULE__{user: user, organization: nil}
  end
end
