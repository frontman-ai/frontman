defmodule FrontmanServer.OrganizationsFixtures do
  def unique_organization_slug, do: "some slug#{System.unique_integer([:positive])}"

  def organization_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "some name",
        slug: unique_organization_slug()
      })

    {:ok, organization} = FrontmanServer.Organizations.create_organization(scope, attrs)
    organization
  end

  def membership_fixture(scope, target_user, role \\ :member) do
    {:ok, membership} = FrontmanServer.Organizations.add_member(scope, target_user, role)
    membership
  end
end
