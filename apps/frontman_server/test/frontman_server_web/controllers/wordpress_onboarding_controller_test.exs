defmodule FrontmanServerWeb.WordPressOnboardingControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.WordPress.Connection

  test "requires sign in and retains the return path", %{conn: conn} do
    conn = get(conn, ~p"/wordpress/connect?check=1")
    assert redirected_to(conn) == ~p"/users/log-in"
    assert get_session(conn, :user_return_to) == "/wordpress/connect?check=1"
  end

  test "the connection check reflects only the signed-in account's stored sites", %{conn: conn} do
    owner = Accounts.user_fixture()
    other = Accounts.user_fixture()
    insert_site(other, "private.example")
    conn = log_in_user(conn, owner)

    conn = get(conn, ~p"/wordpress/connect")
    response = html_response(conn, 200)
    document = LazyHTML.from_document(response)
    assert LazyHTML.text(LazyHTML.query(document, "#frontman-sign-in")) =~ owner.email
    assert LazyHTML.query(document, "#check-result") |> LazyHTML.to_tree() == []
    assert LazyHTML.query(document, "#connected-sites") |> LazyHTML.to_tree() == []

    assert LazyHTML.attribute(LazyHTML.query(document, "#install-plugin"), "href") == [
             "https://wordpress.org/plugins/frontman-agentic-ai-editor/"
           ]

    assert [check_path] =
             LazyHTML.attribute(LazyHTML.query(document, "#check-connection"), "action")

    check_uri = URI.parse(check_path)
    assert is_nil(check_uri.fragment)
    assert LazyHTML.attribute(LazyHTML.query(document, "#check-connection"), "method") == ["get"]

    assert LazyHTML.attribute(
             LazyHTML.query(document, "#check-connection input[name=check]"),
             "value"
           ) ==
             ["1"]

    check_request = %{check_uri | fragment: nil, query: "check=1"} |> URI.to_string()
    refute response =~ other.email
    refute response =~ "private.example"

    conn = conn |> recycle() |> get(check_request)
    response = html_response(conn, 200)
    document = LazyHTML.from_document(response)
    assert LazyHTML.attribute(LazyHTML.query(document, "#check-result"), "role") == ["status"]
    assert LazyHTML.attribute(LazyHTML.query(document, "#check-result"), "tabindex") == ["-1"]
    assert LazyHTML.query(document, "#check-result[autofocus]") |> LazyHTML.to_tree() != []
    assert LazyHTML.query(document, "#no-connected-sites") |> LazyHTML.to_tree() != []
    assert LazyHTML.query(document, "#connected-sites") |> LazyHTML.to_tree() == []

    insert_site(owner, "owned.example")

    response = conn |> recycle() |> get(check_request) |> html_response(200)
    document = LazyHTML.from_document(response)
    assert LazyHTML.attribute(LazyHTML.query(document, "#check-result"), "role") == ["status"]
    assert LazyHTML.query(document, "#no-connected-sites") |> LazyHTML.to_tree() == []
    assert LazyHTML.text(LazyHTML.query(document, "#connected-sites")) =~ "owned.example"
    refute response =~ "private.example"
    refute response =~ other.email
    refute response =~ "secret-user"
    refute response =~ "secret-password"
  end

  defp insert_site(user, host) do
    %Connection{user_id: user.id}
    |> Connection.changeset(%{
      catalog_url: "https://#{host}/tools",
      call_url: "https://#{host}/tools/call",
      username: "secret-user",
      password: "secret-password"
    })
    |> Repo.insert!()
  end
end
