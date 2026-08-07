defmodule FrontmanServer.Accounts.Scope do
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Organizations.Organization

  defstruct user: nil,
            organization: nil

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

  def user(%__MODULE__{user: %User{} = user}), do: user

  def user_id(%__MODULE__{} = scope), do: user(scope).id

  def user_email(%__MODULE__{} = scope), do: user(scope).email

  def user_name(%__MODULE__{} = scope), do: user(scope).name
end
