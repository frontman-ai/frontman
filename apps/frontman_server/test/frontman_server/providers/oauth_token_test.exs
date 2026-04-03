defmodule FrontmanServer.Providers.OAuthTokenTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Providers.OAuthToken

  describe "changeset/2" do
    test "valid attributes create valid changeset" do
      attrs = %{
        provider: "anthropic",
        access_token: "access_123",
        refresh_token: "refresh_456",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      changeset = OAuthToken.changeset(%OAuthToken{}, attrs)
      assert changeset.valid?
    end

    test "requires provider" do
      attrs = %{
        access_token: "access_123",
        refresh_token: "refresh_456",
        expires_at: DateTime.utc_now()
      }

      changeset = OAuthToken.changeset(%OAuthToken{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).provider
    end

    test "requires access_token" do
      attrs = %{
        provider: "anthropic",
        refresh_token: "refresh_456",
        expires_at: DateTime.utc_now()
      }

      changeset = OAuthToken.changeset(%OAuthToken{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).access_token
    end

    test "requires refresh_token" do
      attrs = %{
        provider: "anthropic",
        access_token: "access_123",
        expires_at: DateTime.utc_now()
      }

      changeset = OAuthToken.changeset(%OAuthToken{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).refresh_token
    end

    test "requires expires_at" do
      attrs = %{
        provider: "anthropic",
        access_token: "access_123",
        refresh_token: "refresh_456"
      }

      changeset = OAuthToken.changeset(%OAuthToken{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).expires_at
    end

    test "validates provider length" do
      attrs = %{
        provider: String.duplicate("a", 65),
        access_token: "access_123",
        refresh_token: "refresh_456",
        expires_at: DateTime.utc_now()
      }

      changeset = OAuthToken.changeset(%OAuthToken{}, attrs)
      refute changeset.valid?
      assert "should be at most 64 character(s)" in errors_on(changeset).provider
    end

    test "does not accept user_id from attrs (security)" do
      user = user_fixture()

      attrs = %{
        provider: "anthropic",
        access_token: "access_123",
        refresh_token: "refresh_456",
        expires_at: DateTime.utc_now(),
        user_id: user.id
      }

      changeset = OAuthToken.changeset(%OAuthToken{}, attrs)
      # user_id should not be in the changes (not cast)
      refute Map.has_key?(changeset.changes, :user_id)
    end
  end

  describe "expired?/1" do
    test "returns true for past expiration" do
      token = %OAuthToken{
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :second)
      }

      assert OAuthToken.expired?(token)
    end

    test "returns false for future expiration" do
      token = %OAuthToken{
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      refute OAuthToken.expired?(token)
    end
  end

  describe "for_user_and_provider/3" do
    test "builds correct query" do
      user = user_fixture()
      query = OAuthToken.for_user_and_provider(user.id, "anthropic")

      # Query should be an Ecto.Query
      assert %Ecto.Query{} = query
    end
  end
end
