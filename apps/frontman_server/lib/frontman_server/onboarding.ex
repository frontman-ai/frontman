defmodule FrontmanServer.Onboarding do
  @moduledoc """
  Orchestrates user onboarding workflows that span multiple contexts.

  This module coordinates operations between Accounts and Organizations
  contexts when they need to happen atomically. It exists to keep individual
  contexts isolated from each other while still supporting cross-cutting
  business operations.
  """

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Organizations
  alias FrontmanServer.Repo

  @doc """
  Registers a user with their first organization atomically.

  Creates a user and their initial organization in a single transaction.
  The user becomes the owner of the organization.

  ## Examples

      iex> register_user_with_organization(%{email: "user@example.com", name: "Jane"}, %{name: "Acme"})
      {:ok, %{user: %User{}, organization: %Organization{}}}

      iex> register_user_with_organization(%{email: "invalid"}, %{name: "Acme"})
      {:error, :user, %Ecto.Changeset{}}

  """
  def register_user_with_organization(user_attrs, org_attrs) do
    Repo.transact(fn ->
      with {:ok, user} <- Accounts.register_user(user_attrs),
           scope = Scope.for_user(user),
           {:ok, organization} <- Organizations.create_organization(scope, org_attrs) do
        {:ok, %{user: user, organization: organization}}
      else
        {:error, changeset} -> {:error, :user, changeset}
      end
    end)
  end
end
