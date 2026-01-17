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
  end

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
