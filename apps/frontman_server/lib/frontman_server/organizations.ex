defmodule FrontmanServer.Organizations do
  use Boundary,
    deps: [FrontmanServer],
    exports: [Organization]

  alias FrontmanServer.Organizations.{Membership, Organization}
  alias FrontmanServer.Repo

  def list_organizations(scope) do
    user_id = scope_user_id(scope)

    Organization
    |> Organization.for_user(user_id)
    |> Organization.ordered_by_name()
    |> Repo.all()
  end

  def get_organization!(scope, id) do
    user_id = scope_user_id(scope)

    Organization
    |> Organization.for_user(user_id)
    |> Repo.get!(id)
  end

  def get_organization_by_slug(scope, slug) do
    user_id = scope_user_id(scope)

    Organization
    |> Organization.for_user(user_id)
    |> Organization.by_slug(slug)
    |> Repo.one()
  end

  def create_organization(scope, attrs) do
    user_id = scope_user_id(scope)

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

  def update_organization(%{organization: %Organization{} = organization} = scope, attrs) do
    with :ok <- authorize_owner(scope),
         {:ok, organization} <- organization |> Organization.changeset(attrs) |> Repo.update() do
      broadcast_organization(scope, {:updated, organization})
      {:ok, organization}
    end
  end

  def delete_organization(%{organization: %Organization{} = organization} = scope) do
    with :ok <- authorize_owner(scope),
         {:ok, organization} <- Repo.delete(organization) do
      broadcast_organization(scope, {:deleted, organization})
      {:ok, organization}
    end
  end

  def change_organization(
        %{organization: %Organization{} = organization} = scope,
        attrs \\ %{}
      ) do
    with :ok <- authorize_owner(scope) do
      Organization.changeset(organization, attrs)
    end
  end

  def list_members(%{organization: %Organization{id: org_id}}) do
    Membership
    |> Membership.for_organization(org_id)
    |> Membership.with_user()
    |> Repo.all()
  end

  def get_membership(%{organization: %Organization{id: org_id}}, %{id: user_id}) do
    Membership
    |> Membership.for_organization(org_id)
    |> Membership.for_user(user_id)
    |> Repo.one()
  end

  def owner?(%{organization: %Organization{id: org_id}} = scope) do
    user_id = scope_user_id(scope)

    Membership
    |> Membership.for_organization(org_id)
    |> Membership.for_user(user_id)
    |> Membership.with_role(:owner)
    |> Repo.exists?()
  end

  def member?(%{organization: %Organization{id: org_id}} = scope) do
    user_id = scope_user_id(scope)

    Membership
    |> Membership.for_organization(org_id)
    |> Membership.for_user(user_id)
    |> Repo.exists?()
  end

  def add_member(
        %{organization: %Organization{id: org_id}} = scope,
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

  def remove_member(%{organization: %Organization{}} = scope, target_user) do
    with :ok <- authorize_owner(scope),
         %Membership{} = membership <- get_membership(scope, target_user) || {:error, :not_found},
         {:ok, membership} <- Repo.delete(membership) do
      broadcast_membership(scope, {:deleted, membership})
      {:ok, membership}
    end
  end

  def update_member_role(%{organization: %Organization{}} = scope, target_user, role) do
    with :ok <- authorize_owner(scope),
         %Membership{} = membership <- get_membership(scope, target_user) || {:error, :not_found},
         {:ok, membership} <- membership |> Membership.changeset(%{role: role}) |> Repo.update() do
      broadcast_membership(scope, {:updated, membership})
      {:ok, membership}
    end
  end

  def subscribe_organizations(scope) do
    key = scope_user_id(scope)

    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "user:#{key}:organizations")
  end

  defp broadcast_organization(scope, message) do
    key = scope_user_id(scope)

    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, "user:#{key}:organizations", message)
  end

  defp broadcast_membership(%{organization: %Organization{id: org_id}}, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, "organization:#{org_id}:memberships", message)
  end

  defp scope_user_id(%{user: %{id: user_id}}), do: user_id

  defp authorize_owner(scope) do
    if owner?(scope), do: :ok, else: {:error, :unauthorized}
  end
end
