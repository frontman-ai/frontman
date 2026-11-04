defmodule FrontmanServerWeb.MCPSitesTest do
  use FrontmanServer.DataCase, async: true

  alias Anubis.Server.{Context, Frame}
  alias Anubis.Server.Handlers.Tools
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.WordPress.Connection
  alias FrontmanServerWeb.MCP.Server

  test "SDK lists only the authenticated account's sites without credentials or endpoints" do
    owner = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    first = insert_site(owner, "first.example")
    second = insert_site(owner, "second.example")
    insert_site(other, "private.example")
    frame = %Frame{context: %Context{auth: %{sub: owner.id}}}

    assert {:reply, %{"tools" => [%{name: "list_sites"}]}, _} =
             Tools.handle_list(%{}, frame, Server)

    request = %{"params" => %{"name" => "list_sites", "arguments" => %{}}}

    assert {:reply, %{"content" => [%{"text" => text}]}, _} =
             Tools.handle_call(request, frame, Server)

    assert %{"sites" => sites} = Jason.decode!(text)

    assert Enum.sort(sites) ==
             Enum.sort([
               %{"id" => first.id, "label" => "first.example"},
               %{"id" => second.id, "label" => "second.example"}
             ])

    refute text =~ "private.example"
    refute text =~ "secret"
    refute text =~ "/tools"
  end

  test "empty accounts return no sites and missing subjects fail closed" do
    user = AccountsFixtures.user_fixture()
    request = %{"params" => %{"name" => "list_sites", "arguments" => %{}}}
    frame = %Frame{context: %Context{auth: %{sub: user.id}}}

    assert {:reply, %{"content" => [%{"text" => text}]}, _} =
             Tools.handle_call(request, frame, Server)

    assert Jason.decode!(text) == %{"sites" => []}
    assert {:error, _, _} = Tools.handle_call(request, %Frame{}, Server)
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
