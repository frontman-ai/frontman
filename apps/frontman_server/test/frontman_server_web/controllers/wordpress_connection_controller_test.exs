defmodule FrontmanServerWeb.WordPressConnectionControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.WordPress.Connection

  test "requires embedded authentication", %{conn: conn} do
    conn = post(conn, ~p"/api/wordpress/connections", %{})
    assert json_response(conn, 401)["error"] == "authentication_required"

    conn =
      get(build_conn(), ~p"/api/wordpress/connections/status?catalog_url=https://example.com")

    assert json_response(conn, 401)["error"] == "authentication_required"
  end

  test "credentials are encrypted and status reports only an exact catalog for its owner" do
    owner = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    url = "https://example.com/?rest_route=/frontman/v1/tools"
    auth = embedded_client_auth(owner)
    path = fn catalog -> ~p"/api/wordpress/connections/status?#{%{catalog_url: catalog}}" end
    status = fn token, catalog -> bearer_get(build_conn(), token, path.(catalog)) end

    assert json_response(status.(auth, url), 200) == %{"connected" => false}

    password = "private-password"

    connection =
      %Connection{user_id: owner.id}
      |> Connection.changeset(%{
        catalog_url: url,
        call_url: "https://example.com/call",
        username: "private-user",
        password: password
      })
      |> Repo.insert!()

    assert %{rows: [[ciphertext]]} =
             Repo.query!("SELECT password FROM wordpress_connections WHERE id = $1", [
               Ecto.UUID.dump!(connection.id)
             ])

    refute ciphertext =~ password
    refute inspect(connection) =~ password
    assert Repo.get!(Connection, connection.id).user_id == owner.id

    response = status.(auth, url)
    assert json_response(response, 200) == %{"connected" => true}
    assert get_resp_header(response, "cache-control") == ["no-store"]
    assert json_response(status.(auth, url <> "/"), 200) == %{"connected" => false}

    assert json_response(status.(embedded_client_auth(other), url), 200) == %{
             "connected" => false
           }

    missing = bearer_get(build_conn(), auth, ~p"/api/wordpress/connections/status")
    assert json_response(missing, 400) == %{"error" => "catalog_url is required"}
    assert get_resp_header(missing, "cache-control") == ["no-store"]
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
end
