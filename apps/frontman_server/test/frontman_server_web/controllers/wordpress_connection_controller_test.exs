defmodule FrontmanServerWeb.WordPressConnectionControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.{Repo, WordPress}
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.WordPress.Connection

  test "requires embedded authentication", %{conn: conn} do
    conn = post(conn, ~p"/api/wordpress/connections", %{})
    assert json_response(conn, 401)["error"] == "authentication_required"
  end

  test "rejects non-HTTPS and private destinations without saving" do
    user = AccountsFixtures.user_fixture()
    auth = embedded_client_auth(user)

    for url <- ["http://example.com", "https://127.0.0.1"] do
      conn =
        bearer_post(build_conn(), auth, ~p"/api/wordpress/connections", %{
          catalog_url: url,
          call_url: url,
          username: "test",
          password: "test-password"
        })

      assert json_response(conn, 422)["error"] == "Connection failed"
    end

    assert Repo.aggregate(Connection, :count) == 0
  end

  test "encrypts credentials and rejects access by another owner" do
    owner = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    password = "local-test-password"

    connection =
      %Connection{user_id: owner.id}
      |> Connection.changeset(%{
        catalog_url: "https://example.com/tools",
        call_url: "https://example.com/tools/call",
        username: "test",
        password: password
      })
      |> Repo.insert!()

    assert %{rows: [[ciphertext]]} =
             Repo.query!("SELECT password FROM wordpress_connections WHERE id = $1", [
               Ecto.UUID.dump!(connection.id)
             ])

    refute ciphertext =~ password
    refute inspect(connection) =~ password

    assert {:error, :request_failed} =
             WordPress.read_post(Scope.for_user(other), connection.id, 1)

    assert {:error, :request_failed} =
             WordPress.read_post(Scope.for_user(owner), Ecto.UUID.generate(), 1)
  end
end
