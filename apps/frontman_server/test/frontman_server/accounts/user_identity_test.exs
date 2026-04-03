defmodule FrontmanServer.Accounts.UserIdentityTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Accounts.UserIdentity

  import FrontmanServer.Test.Fixtures.Accounts

  describe "changeset/2" do
    setup do
      %{user: user_fixture()}
    end

    test "valid attributes", %{user: user} do
      attrs = valid_identity_attributes(user_id: user.id)
      changeset = UserIdentity.changeset(%UserIdentity{}, attrs)
      assert changeset.valid?
    end

    test "requires provider", %{user: user} do
      attrs = valid_identity_attributes(user_id: user.id) |> Map.delete(:provider)
      changeset = UserIdentity.changeset(%UserIdentity{}, attrs)
      assert %{provider: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires provider_id", %{user: user} do
      attrs = valid_identity_attributes(user_id: user.id) |> Map.delete(:provider_id)
      changeset = UserIdentity.changeset(%UserIdentity{}, attrs)
      assert %{provider_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires user_id", %{user: _user} do
      attrs = valid_identity_attributes()
      changeset = UserIdentity.changeset(%UserIdentity{}, attrs)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates provider is github or google", %{user: user} do
      attrs = valid_identity_attributes(user_id: user.id, provider: "invalid")
      changeset = UserIdentity.changeset(%UserIdentity{}, attrs)
      assert %{provider: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts github provider", %{user: user} do
      attrs = valid_identity_attributes(user_id: user.id, provider: "github")
      changeset = UserIdentity.changeset(%UserIdentity{}, attrs)
      assert changeset.valid?
    end

    test "accepts google provider", %{user: user} do
      attrs = valid_identity_attributes(user_id: user.id, provider: "google")
      changeset = UserIdentity.changeset(%UserIdentity{}, attrs)
      assert changeset.valid?
    end

    test "enforces unique user_id + provider", %{user: user} do
      _existing = identity_fixture(user, provider: "github")

      {:error, changeset} =
        %UserIdentity{}
        |> UserIdentity.changeset(valid_identity_attributes(user_id: user.id, provider: "github"))
        |> Repo.insert()

      assert %{user_id: ["you have already connected this provider"]} = errors_on(changeset)
    end

    test "enforces unique provider + provider_id", %{user: user} do
      existing = identity_fixture(user, provider: "github")
      other_user = user_fixture()

      {:error, changeset} =
        %UserIdentity{}
        |> UserIdentity.changeset(
          valid_identity_attributes(
            user_id: other_user.id,
            provider: "github",
            provider_id: existing.provider_id
          )
        )
        |> Repo.insert()

      assert %{provider: ["this account is already linked to another user"]} =
               errors_on(changeset)
    end
  end

  describe "touch_changeset/1" do
    test "updates last_signed_in_at" do
      user = user_fixture()
      identity = identity_fixture(user)
      assert is_nil(identity.last_signed_in_at)

      changeset = UserIdentity.touch_changeset(identity)
      assert changeset.changes.last_signed_in_at
    end
  end
end
