defmodule FrontmanServerWeb.MCPSitesTest do
  use FrontmanServer.DataCase, async: false

  alias Anubis.Server.{Context, Frame}
  alias Anubis.Server.Handlers.Tools
  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug
  alias Anubis.Server.Transport.StreamableHTTP.StatelessBinding
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.WordPress
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

  test "parsed SDK calls reject absent, malformed and foreign selectors before discovery" do
    owner = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    owned = insert_site(owner, "owner.invalid")
    foreign = insert_site(other, "foreign.invalid")
    frame = %Frame{context: %Context{auth: %{sub: owner.id}}, assigns: %{mcp_request: :original}}
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(handler, [:finch, :request, :start], &__MODULE__.record_request/4, self())

    on_exit(fn -> :telemetry.detach(handler) end)

    for arguments <- [%{}, %{"site_id" => "bad"}, %{"site_id" => foreign.id}] do
      request = %{
        "method" => "tools/call",
        "params" => %{"name" => "wp_read_post", "arguments" => arguments}
      }

      assert {:error, _, returned} = Server.handle_request(request, frame)
      assert returned.assigns.mcp_request == :original
    end

    Repo.delete!(owned)

    for id <- [foreign.id, "bad", owned.id] do
      assert {:error, :connection_failed} = WordPress.catalog(Scope.for_user(owner), id, 1_000)
    end

    refute_received {:outbound, "owner.invalid"}
    refute_received {:outbound, "foreign.invalid"}
  end

  test "the SDK request hook restores its temporary request after list_sites" do
    user = AccountsFixtures.user_fixture()
    site = insert_site(user, "owned.example")
    frame = %Frame{context: %Context{auth: %{sub: user.id}}}
    request = %{"method" => "tools/call", "params" => %{"name" => "list_sites"}}

    assert {:reply, %{"content" => [%{"text" => text}]}, returned} =
             Server.handle_request(request, frame)

    assert Jason.decode!(text) == %{"sites" => [%{"id" => site.id, "label" => "owned.example"}]}
    refute Map.has_key?(returned.assigns, :mcp_request)
  end

  test "stateless SDK binding parses and dispatches a request with verified claims" do
    user = AccountsFixtures.user_fixture()
    site = insert_site(user, "owned.example")

    body = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/call",
      "params" => %{
        "name" => "list_sites",
        "arguments" => %{},
        "_meta" => %{
          "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
          "io.modelcontextprotocol/clientCapabilities" => %{},
          "io.modelcontextprotocol/clientInfo" => %{"name" => "test", "version" => "1"}
        }
      }
    }

    conn =
      Plug.Test.conn(:post, "/mcp", Jason.encode!(body))
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("mcp-protocol-version", "2026-07-28")
      |> Plug.Conn.put_req_header("mcp-method", "tools/call")
      |> Plug.Conn.put_req_header("mcp-name", "list_sites")

    context = %{auth: %{sub: user.id}, assigns: %{}, req_headers: conn.req_headers}
    response = StatelessBinding.call(conn, "2026-07-28", context, AnubisPlug.init(server: Server))

    assert %{"result" => %{"content" => [%{"text" => text}]}} = Jason.decode!(response.resp_body)
    assert Jason.decode!(text) == %{"sites" => [%{"id" => site.id, "label" => "owned.example"}]}

    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(handler, [:finch, :request, :start], &__MODULE__.record_request/4, self())

    on_exit(fn -> :telemetry.detach(handler) end)
    body = put_in(body, ["params", "name"], "wp_read_post")
    body = put_in(body, ["params", "arguments"], %{"site_id" => Ecto.UUID.generate()})

    conn =
      Plug.Test.conn(:post, "/mcp", Jason.encode!(body))
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("mcp-protocol-version", "2026-07-28")
      |> Plug.Conn.put_req_header("mcp-method", "tools/call")
      |> Plug.Conn.put_req_header("mcp-name", "wp_read_post")

    response = StatelessBinding.call(conn, "2026-07-28", context, AnubisPlug.init(server: Server))
    assert %{"error" => _} = Jason.decode!(response.resp_body)
    refute_received {:outbound, "owned.example"}
  end

  test "input augmentation accepts literal reference names but rejects unsafe schema positions" do
    base = %{
      "type" => "object",
      "properties" => %{
        "$ref" => %{"type" => "string", "default" => %{"$ref" => "literal"}},
        "id" => %{"type" => "integer", "minimum" => 1}
      },
      "required" => ["id"]
    }

    assert Server.supported_input?(base)

    for schema <- [
          Map.put(base, "$ref", "#/$defs/id"),
          Map.put(base, "const", %{}),
          Map.put(base, "enum", [%{}]),
          put_in(base, ["properties", "id", "pattern"], 42),
          put_in(base, ["properties", "id", "x-mcp-header"], "Id"),
          put_in(base, ["properties", "site_id"], %{"type" => "string"})
        ] do
      refute Server.supported_input?(schema)
    end
  end

  test "catalog union preserves provenance, rejects conflicts and includes more than 32 sites" do
    schema = %{"type" => "object", "properties" => %{"id" => %{"type" => "integer"}}}

    entries =
      for n <- 1..33 do
        {Ecto.UUID.generate(), %{"name" => "tool_#{n}", "inputSchema" => schema}}
      end

    [{site, first} | _] = entries
    other = Ecto.UUID.generate()
    unsupported = Map.put(first, "outputSchema", %{"type" => "object"})
    conflict = Map.put(first, "inputSchema", %{"type" => "object"})
    reserved = %{"name" => "list_sites", "inputSchema" => schema}
    tools = Server.catalog_tools(entries ++ [{other, first}, {other, reserved}], ["list_sites"])

    assert length(tools) == 33
    tool = Enum.find(tools, &(&1.name == first["name"]))
    assert tool.input_schema["required"] == ["site_id"]
    assert tool.input_schema["properties"]["id"] == %{"type" => "integer"}

    assert {:ok, %{"site_id" => ^site, "id" => 1}} =
             tool.validate_input.(%{"site_id" => site, "id" => 1})

    assert {:error, _} = tool.validate_input.(%{"site_id" => Ecto.UUID.generate()})

    assert Server.catalog_tools([{other, unsupported}], []) == []
    assert Server.catalog_tools([{other, Map.put(first, "outputSchema", nil)}], []) == []

    refute Enum.any?(
             Server.catalog_tools(entries ++ [{other, conflict}], []),
             &(&1.name == first["name"])
           )
  end

  def record_request(_event, _measurements, %{request: request}, test) do
    send(test, {:outbound, request.host})
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
