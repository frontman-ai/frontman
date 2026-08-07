defmodule FrontmanServer.OrganizationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FrontmanServer.Organizations` context.
  """

  @doc """
  Generate a unique organization slug.
  """
  def unique_organization_slug, do: "some slug#{System.unique_integer([:positive])}"

  @doc """
  Generate a organization.
  """
  def organization_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "some name",
        slug: unique_organization_slug()
      })

    {:ok, organization} = FrontmanServer.Organizations.create_organization(scope, attrs)
    organization
  end

  @doc """
  Add a member to an organization.

  Expects a scope with organization already set.
  The scope user must be an owner of the organization.
  """
  def membership_fixture(scope, target_user, role \\ :member) do
    {:ok, membership} = FrontmanServer.Organizations.add_member(scope, target_user, role)
    membership
  end
end
