defmodule FrontmanServer.Organizations do
  @moduledoc """
  Manages organizations and team membership.

  Organizations are workspaces that group users together. Each user can belong
  to multiple organizations with different roles (owner, member).

  ## Organization Lifecycle
  - Users create organizations and become the owner
  - Owners can invite other users as members
  - Organizations are accessed via URL slug (e.g., /orgs/my-team)

  ## Authorization
  All functions require a Scope. Functions operating on a specific organization
  expect the organization to be set in the scope (via FetchOrganization plug).
  Owner-only operations will raise MatchError if the scoped user lacks permission.
  """

  import Ecto.Query, warn: false

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Organizations.{Membership, Organization}
  alias FrontmanServer.Repo

  # ==============================================================================
  # Organization Queries
  # ==============================================================================

  @doc """
  Returns the list of organizations the scoped user belongs to.

  ## Examples

      iex> list_organizations(scope)
      [%Organization{}, ...]

  """
  def list_organizations(%Scope{user: %{id: user_id}}) do
    Organization
    |> Organization.for_user(user_id)
    |> Organization.ordered_by_name()
    |> Repo.all()
  end

  @doc """
  Gets a single organization by ID.

  Raises `Ecto.NoResultsError` if the Organization does not exist or user is not a member.

  ## Examples

      iex> get_organization!(scope, 123)
      %Organization{}

      iex> get_organization!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_organization!(%Scope{user: %{id: user_id}}, id) do
    Organization
    |> Organization.for_user(user_id)
    |> Repo.get!(id)
  end

  @doc """
  Gets an organization by slug if the scoped user is a member.

  Returns nil if not found or user is not a member.

  ## Examples

      iex> get_organization_by_slug(scope, "my-org")
      %Organization{}

      iex> get_organization_by_slug(scope, "unknown-org")
      nil

  """
  def get_organization_by_slug(%Scope{user: %{id: user_id}}, slug) do
    Organization
    |> Organization.for_user(user_id)
    |> Organization.by_slug(slug)
    |> Repo.one()
  end

  # ==============================================================================
  # Organization Commands
  # ==============================================================================

  @doc """
  Creates an organization with the scoped user as owner.

  ## Examples

      iex> create_organization(scope, %{name: "My Org"})
      {:ok, %Organization{}}

      iex> create_organization(scope, %{})
      {:error, %Ecto.Changeset{}}

  """
  def create_organization(%Scope{user: %{id: user_id}} = scope, attrs) do
    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:organization, Organization.changeset(%Organization{}, attrs))
      |> Ecto.Multi.insert(:membership, fn %{organization: org} ->
        Membership.changeset(%Membership{}, %{
          user_id: user_id,
          organization_id: org.id,
          role: :owner
        })
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{organization: organization}} ->
        broadcast_organization(scope, {:created, organization})
        {:ok, organization}

      {:error, :organization, changeset, _} ->
        {:error, changeset}

      {:error, :membership, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates the organization in the current scope.

  Requires the scoped user to be an owner.

  ## Examples

      iex> update_organization(scope, %{name: "New Name"})
      {:ok, %Organization{}}

      iex> update_organization(scope, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_organization(%Scope{organization: %Organization{} = organization} = scope, attrs) do
    with :ok <- authorize_owner(scope),
         {:ok, organization} <- organization |> Organization.changeset(attrs) |> Repo.update() do
      broadcast_organization(scope, {:updated, organization})
      {:ok, organization}
    end
  end

  @doc """
  Deletes the organization in scope.

  Requires the scoped user to be an owner.

  ## Examples

      iex> delete_organization(scope)
      {:ok, %Organization{}}

      iex> delete_organization(scope)
      {:error, %Ecto.Changeset{}}

  """
  def delete_organization(%Scope{organization: %Organization{} = organization} = scope) do
    with :ok <- authorize_owner(scope),
         {:ok, organization} <- Repo.delete(organization) do
      broadcast_organization(scope, {:deleted, organization})
      {:ok, organization}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking organization changes.

  Requires the scoped user to be an owner.

  ## Examples

      iex> change_organization(scope)
      %Ecto.Changeset{data: %Organization{}}

  """
  def change_organization(
        %Scope{organization: %Organization{} = organization} = scope,
        attrs \\ %{}
      ) do
    with :ok <- authorize_owner(scope) do
      Organization.changeset(organization, attrs)
    end
  end

  # ==============================================================================
  # Membership Queries
  # ==============================================================================

  @doc """
  Returns the list of members for the organization in scope.
  """
  def list_members(%Scope{organization: %Organization{id: org_id}}) do
    Membership
    |> Membership.for_organization(org_id)
    |> Membership.with_user()
    |> Repo.all()
  end

  @doc """
  Gets the membership for a user in the organization in scope.
  """
  def get_membership(%Scope{organization: %Organization{id: org_id}}, %{id: user_id}) do
    Membership
    |> Membership.for_organization(org_id)
    |> Membership.for_user(user_id)
    |> Repo.one()
  end

  @doc """
  Returns `true` if the scoped user is an owner of the organization in scope.
  """
  def owner?(%Scope{user: %{id: user_id}, organization: %Organization{id: org_id}}) do
    Membership
    |> Membership.for_organization(org_id)
    |> Membership.for_user(user_id)
    |> Membership.with_role(:owner)
    |> Repo.exists?()
  end

  @doc """
  Returns `true` if the scoped user is a member of the organization in scope (any role).
  """
  def member?(%Scope{user: %{id: user_id}, organization: %Organization{id: org_id}}) do
    Membership
    |> Membership.for_organization(org_id)
    |> Membership.for_user(user_id)
    |> Repo.exists?()
  end

  # ==============================================================================
  # Membership Commands
  # ==============================================================================

  @doc """
  Adds a user to the organization in scope with the given role.

  Requires the scoped user to be an owner.
  """
  def add_member(
        %Scope{organization: %Organization{id: org_id}} = scope,
        target_user,
        role \\ :member
      ) do
    with :ok <- authorize_owner(scope),
         {:ok, membership} <-
           %Membership{}
           |> Membership.changeset(%{
             organization_id: org_id,
             user_id: target_user.id,
             role: role
           })
           |> Repo.insert() do
      broadcast_membership(scope, {:created, membership})
      {:ok, membership}
    end
  end

  @doc """
  Removes a user from the organization in scope.

  Requires the scoped user to be an owner.
  """
  def remove_member(%Scope{organization: %Organization{}} = scope, target_user) do
    with :ok <- authorize_owner(scope),
         %Membership{} = membership <- get_membership(scope, target_user) || {:error, :not_found},
         {:ok, membership} <- Repo.delete(membership) do
      broadcast_membership(scope, {:deleted, membership})
      {:ok, membership}
    end
  end

  @doc """
  Updates a member's role in the organization in scope.

  Requires the scoped user to be an owner.
  """
  def update_member_role(%Scope{organization: %Organization{}} = scope, target_user, role) do
    with :ok <- authorize_owner(scope),
         %Membership{} = membership <- get_membership(scope, target_user) || {:error, :not_found},
         {:ok, membership} <- membership |> Membership.changeset(%{role: role}) |> Repo.update() do
      broadcast_membership(scope, {:updated, membership})
      {:ok, membership}
    end
  end

  # ==============================================================================
  # PubSub
  # ==============================================================================

  @doc """
  Subscribes to scoped notifications about any organization changes.

  The broadcasted messages match the pattern:

    * {:created, %Organization{}}
    * {:updated, %Organization{}}
    * {:deleted, %Organization{}}

  """
  def subscribe_organizations(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "user:#{key}:organizations")
  end

  defp broadcast_organization(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, "user:#{key}:organizations", message)
  end

  defp broadcast_membership(%Scope{organization: %Organization{id: org_id}}, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, "organization:#{org_id}:memberships", message)
  end

  defp authorize_owner(scope) do
    if owner?(scope), do: :ok, else: {:error, :unauthorized}
  end
end
