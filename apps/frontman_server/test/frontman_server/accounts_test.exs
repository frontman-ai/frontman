defmodule FrontmanServer.AccountsTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Accounts

  import FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.Accounts.{Scope, User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_magic_link_token/1" do
    setup do
      user = user_fixture()
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      %{user: user, token: encoded_token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_magic_link_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_magic_link_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_magic_link_token(token)
    end
  end

  describe "login_user_by_magic_link/1" do
    test "confirms user and expires tokens" do
      user = unconfirmed_user_fixture()
      refute user.confirmed_at
      {encoded_token, hashed_token} = generate_user_magic_link_token(user)

      assert {:ok, {user, [%{token: ^hashed_token}]}} =
               Accounts.login_user_by_magic_link(encoded_token)

      assert user.confirmed_at
    end

    test "returns user and (deleted) token for confirmed user" do
      user = user_fixture()
      assert user.confirmed_at
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      assert {:ok, {^user, []}} = Accounts.login_user_by_magic_link(encoded_token)
      assert {:error, :not_found} = Accounts.login_user_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed user has password set" do
      user = unconfirmed_user_fixture()
      query = from(u in User, where: u.id == ^user.id)
      {1, nil} = Repo.update_all(query, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_user_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "embedded client tokens" do
    setup do
      %{user: user_fixture(), approved_origin: "https://customer.example"}
    end

    test "generates an opaque token and stores only its hash", %{
      user: user,
      approved_origin: approved_origin
    } do
      token = Accounts.generate_embedded_client_token(user, approved_origin)
      {:ok, decoded_token} = Base.url_decode64(token, padding: false)

      stored_token = Repo.get_by!(UserToken, token: :crypto.hash(:sha256, decoded_token))
      assert stored_token.token == :crypto.hash(:sha256, decoded_token)
      refute stored_token.token == token
      assert stored_token.context == "embedded_client"
      assert stored_token.user_id == user.id
      assert stored_token.approved_origin == approved_origin
      assert stored_token.expires_at != nil
      assert is_nil(stored_token.last_used_at)
    end

    test "returns scope and token record for a valid token", %{
      user: user,
      approved_origin: approved_origin
    } do
      token = Accounts.generate_embedded_client_token(user, approved_origin)
      stored_token = user_token_by_raw_token(token)

      assert {scope, token_id} =
               Accounts.get_scope_by_embedded_client_token(token, "https://customer.example")

      assert Accounts.scope_user_id(scope) == user.id
      assert token_id == stored_token.id
      assert stored_token.approved_origin == approved_origin
    end

    test "does not return scope when origin does not match", %{user: user} do
      token = Accounts.generate_embedded_client_token(user, "https://customer.example")

      refute Accounts.get_scope_by_embedded_client_token(token, "https://evil.example")
    end

    test "does not return scope for invalid tokens", %{user: user} do
      Accounts.generate_embedded_client_token(user, "https://customer.example")

      refute Accounts.get_scope_by_embedded_client_token("oops", "https://customer.example")
    end

    test "does not return scope for expired tokens", %{
      user: user,
      approved_origin: approved_origin
    } do
      token = Accounts.generate_embedded_client_token(user, approved_origin)
      user_token = user_token_by_raw_token(token)

      {1, nil} =
        user_token.id
        |> UserToken.by_embedded_client_id()
        |> Repo.update_all(
          set: [expires_at: DateTime.add(DateTime.utc_now(:second), -1, :second)]
        )

      refute Accounts.get_scope_by_embedded_client_token(token, "https://customer.example")
    end

    test "updates last_used_at for an embedded client token", %{
      user: user,
      approved_origin: approved_origin
    } do
      token = Accounts.generate_embedded_client_token(user, approved_origin)
      user_token = user_token_by_raw_token(token)
      assert Accounts.touch_embedded_client_token(Scope.for_user(user), user_token.id) == :ok

      touched_token = Repo.get!(UserToken, user_token.id)
      assert touched_token.last_used_at != nil
    end

    test "does not touch another user's embedded client token", %{user: user} do
      other_user = user_fixture()
      token = Accounts.generate_embedded_client_token(other_user, "https://customer.example")
      user_token = user_token_by_raw_token(token)

      assert Accounts.touch_embedded_client_token(Scope.for_user(user), user_token.id) == :ok

      untouched_token = Repo.get!(UserToken, user_token.id)
      assert is_nil(untouched_token.last_used_at)
    end

    test "revokes one embedded client token", %{user: user} do
      first_token = Accounts.generate_embedded_client_token(user, "https://first.example")
      first_user_token = user_token_by_raw_token(first_token)
      second_token = Accounts.generate_embedded_client_token(user, "https://second.example")

      assert Accounts.delete_embedded_client_token(Scope.for_user(user), first_user_token.id) ==
               :ok

      refute Accounts.get_scope_by_embedded_client_token(first_token, "https://first.example")
      assert Accounts.get_scope_by_embedded_client_token(second_token, "https://second.example")
    end

    test "does not revoke another user's embedded client token", %{user: user} do
      other_user = user_fixture()
      token = Accounts.generate_embedded_client_token(other_user, "https://customer.example")
      user_token = user_token_by_raw_token(token)

      assert Accounts.delete_embedded_client_token(Scope.for_user(user), user_token.id) == :ok

      assert Repo.get(UserToken, user_token.id)
    end

    test "revokes all embedded client tokens without deleting session tokens", %{user: user} do
      first_token = Accounts.generate_embedded_client_token(user, "https://first.example")
      second_token = Accounts.generate_embedded_client_token(user, "https://second.example")

      session_token = Accounts.generate_user_session_token(user)

      assert Accounts.delete_all_embedded_client_tokens(user) == :ok
      refute Accounts.get_scope_by_embedded_client_token(first_token, "https://first.example")
      refute Accounts.get_scope_by_embedded_client_token(second_token, "https://second.example")
      assert Accounts.get_user_by_session_token(session_token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{user: unconfirmed_user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "login"
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  defp user_token_by_raw_token(token) do
    {:ok, decoded_token} = Base.url_decode64(token, padding: false)
    Repo.get_by!(UserToken, token: :crypto.hash(:sha256, decoded_token))
  end

  describe "list_user_identities/1" do
    test "returns empty list when user has no identities" do
      user = user_fixture()
      assert Accounts.list_user_identities(user) == []
    end

    test "returns user's identities" do
      user = user_fixture()
      identity = identity_fixture(user, provider: "github")

      [returned_identity] = Accounts.list_user_identities(user)
      assert returned_identity.id == identity.id
      assert returned_identity.provider == "github"
    end

    test "returns multiple identities" do
      user = user_fixture()
      _github = identity_fixture(user, provider: "github")
      _google = identity_fixture(user, provider: "google")

      identities = Accounts.list_user_identities(user)
      assert length(identities) == 2
      assert Enum.any?(identities, &(&1.provider == "github"))
      assert Enum.any?(identities, &(&1.provider == "google"))
    end

    test "does not return other users' identities" do
      user = user_fixture()
      other_user = user_fixture()
      _user_identity = identity_fixture(user, provider: "github")
      _other_identity = identity_fixture(other_user, provider: "google")

      identities = Accounts.list_user_identities(user)
      assert length(identities) == 1
      assert hd(identities).provider == "github"
    end
  end
end
