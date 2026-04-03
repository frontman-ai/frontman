defmodule FrontmanServer.OrganizationsTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Organizations

  import FrontmanServer.Test.Fixtures.Accounts

  describe "create_organization/2" do
    test "creates organization and membership with creator as owner" do
      scope = user_scope_fixture()

      assert {:ok, organization} =
               Organizations.create_organization(scope, %{name: "My Org"})

      assert organization.name == "My Org"
      assert organization.slug == "my-org"

      # Creator should be owner - need org in scope to check
      org_scope = user_scope_fixture(scope.user, organization)
      assert Organizations.owner?(org_scope)
      assert Organizations.member?(org_scope)
    end

    test "auto-generates slug from name" do
      scope = user_scope_fixture()

      {:ok, organization} =
        Organizations.create_organization(scope, %{name: "Some Cool Org!"})

      assert organization.slug == "some-cool-org"
    end

    test "allows custom slug" do
      scope = user_scope_fixture()

      {:ok, organization} =
        Organizations.create_organization(scope, %{name: "My Org", slug: "custom-slug"})

      assert organization.slug == "custom-slug"
    end

    test "requires name" do
      scope = user_scope_fixture()

      assert {:error, changeset} =
               Organizations.create_organization(scope, %{})

      assert "can't be blank" in errors_on(changeset).name
    end

    test "enforces unique slug" do
      scope = user_scope_fixture()

      {:ok, _org1} =
        Organizations.create_organization(scope, %{name: "First", slug: "unique-slug"})

      assert {:error, changeset} =
               Organizations.create_organization(scope, %{name: "Second", slug: "unique-slug"})

      assert "has already been taken" in errors_on(changeset).slug
    end
  end

  describe "list_organizations/1" do
    test "returns only organizations user is a member of" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      {:ok, org1} = Organizations.create_organization(scope1, %{name: "Org 1"})
      {:ok, _org2} = Organizations.create_organization(scope2, %{name: "Org 2"})

      orgs = Organizations.list_organizations(scope1)
      assert length(orgs) == 1
      assert hd(orgs).id == org1.id
    end

    test "returns organizations ordered by name" do
      scope = user_scope_fixture()

      {:ok, _} = Organizations.create_organization(scope, %{name: "Zebra"})
      {:ok, _} = Organizations.create_organization(scope, %{name: "Alpha"})
      {:ok, _} = Organizations.create_organization(scope, %{name: "Beta"})

      orgs = Organizations.list_organizations(scope)
      names = Enum.map(orgs, & &1.name)
      assert names == ["Alpha", "Beta", "Zebra"]
    end
  end

  describe "get_organization!/2" do
    test "returns organization if user is a member" do
      scope = user_scope_fixture()
      {:ok, org} = Organizations.create_organization(scope, %{name: "My Org"})

      assert Organizations.get_organization!(scope, org.id) == org
    end

    test "raises if user is not a member" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      {:ok, org} = Organizations.create_organization(scope1, %{name: "My Org"})

      assert_raise Ecto.NoResultsError, fn ->
        Organizations.get_organization!(scope2, org.id)
      end
    end
  end

  describe "get_organization_by_slug/2" do
    test "returns organization if user is a member" do
      scope = user_scope_fixture()
      {:ok, org} = Organizations.create_organization(scope, %{name: "My Org"})

      assert Organizations.get_organization_by_slug(scope, org.slug) == org
    end

    test "returns nil if user is not a member" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()

      {:ok, org} = Organizations.create_organization(scope1, %{name: "My Org"})

      assert Organizations.get_organization_by_slug(scope2, org.slug) == nil
    end

    test "returns nil if organization does not exist" do
      scope = user_scope_fixture()

      assert Organizations.get_organization_by_slug(scope, "nonexistent-slug") == nil
    end
  end

  describe "update_organization/2" do
    test "owner can update organization" do
      scope = user_scope_fixture()
      {:ok, org} = Organizations.create_organization(scope, %{name: "Old Name"})
      org_scope = user_scope_fixture(scope.user, org)

      assert {:ok, updated} =
               Organizations.update_organization(org_scope, %{name: "New Name"})

      assert updated.name == "New Name"
    end

    test "non-owner cannot update organization" do
      owner_scope = user_scope_fixture()
      member = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      {:ok, _} = Organizations.add_member(owner_org_scope, member, :member)

      member_org_scope = user_scope_fixture(member, org)

      assert {:error, :unauthorized} =
               Organizations.update_organization(member_org_scope, %{name: "Hacked"})
    end
  end

  describe "delete_organization/1" do
    test "owner can delete organization" do
      scope = user_scope_fixture()
      {:ok, org} = Organizations.create_organization(scope, %{name: "My Org"})
      org_scope = user_scope_fixture(scope.user, org)

      assert {:ok, _} = Organizations.delete_organization(org_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Organizations.get_organization!(scope, org.id)
      end
    end

    test "non-owner cannot delete organization" do
      owner_scope = user_scope_fixture()
      member = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      {:ok, _} = Organizations.add_member(owner_org_scope, member, :member)

      member_org_scope = user_scope_fixture(member, org)

      assert {:error, :unauthorized} = Organizations.delete_organization(member_org_scope)
    end
  end

  describe "membership management" do
    test "add_member/3 adds user to organization" do
      owner_scope = user_scope_fixture()
      new_user = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      new_user_org_scope = user_scope_fixture(new_user, org)

      refute Organizations.member?(new_user_org_scope)

      {:ok, membership} = Organizations.add_member(owner_org_scope, new_user, :member)

      assert membership.role == :member
      assert Organizations.member?(new_user_org_scope)
      refute Organizations.owner?(new_user_org_scope)
    end

    test "add_member/3 prevents duplicate memberships" do
      owner_scope = user_scope_fixture()
      new_user = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      {:ok, _} = Organizations.add_member(owner_org_scope, new_user, :member)

      assert {:error, changeset} = Organizations.add_member(owner_org_scope, new_user, :member)
      assert "has already been taken" in errors_on(changeset).user_id
    end

    test "remove_member/2 removes user from organization" do
      owner_scope = user_scope_fixture()
      new_user = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      new_user_org_scope = user_scope_fixture(new_user, org)
      {:ok, _} = Organizations.add_member(owner_org_scope, new_user, :member)

      assert Organizations.member?(new_user_org_scope)

      {:ok, _} = Organizations.remove_member(owner_org_scope, new_user)

      refute Organizations.member?(new_user_org_scope)
    end

    test "update_member_role/3 changes role" do
      owner_scope = user_scope_fixture()
      new_user = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      new_user_org_scope = user_scope_fixture(new_user, org)
      {:ok, _} = Organizations.add_member(owner_org_scope, new_user, :member)

      refute Organizations.owner?(new_user_org_scope)

      {:ok, _} = Organizations.update_member_role(owner_org_scope, new_user, :owner)

      assert Organizations.owner?(new_user_org_scope)
    end

    test "list_members/1 returns all members" do
      owner_scope = user_scope_fixture()
      member1 = user_fixture()
      member2 = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      {:ok, _} = Organizations.add_member(owner_org_scope, member1, :member)
      {:ok, _} = Organizations.add_member(owner_org_scope, member2, :member)

      members = Organizations.list_members(owner_org_scope)

      assert length(members) == 3
    end
  end

  describe "role checks" do
    test "owner?/1 returns true only for owners" do
      owner_scope = user_scope_fixture()
      member = user_fixture()
      outsider = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      {:ok, _} = Organizations.add_member(owner_org_scope, member, :member)

      member_org_scope = user_scope_fixture(member, org)
      outsider_org_scope = user_scope_fixture(outsider, org)

      assert Organizations.owner?(owner_org_scope)
      refute Organizations.owner?(member_org_scope)
      refute Organizations.owner?(outsider_org_scope)
    end

    test "member?/1 returns true for any role" do
      owner_scope = user_scope_fixture()
      member = user_fixture()
      outsider = user_fixture()

      {:ok, org} = Organizations.create_organization(owner_scope, %{name: "My Org"})
      owner_org_scope = user_scope_fixture(owner_scope.user, org)
      {:ok, _} = Organizations.add_member(owner_org_scope, member, :member)

      member_org_scope = user_scope_fixture(member, org)
      outsider_org_scope = user_scope_fixture(outsider, org)

      assert Organizations.member?(owner_org_scope)
      assert Organizations.member?(member_org_scope)
      refute Organizations.member?(outsider_org_scope)
    end
  end
end
