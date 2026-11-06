defmodule FrontmanServerWeb.MCPSitesTest do
  use FrontmanServerWeb.ConnCase, async: false

  alias Anubis.Server.{Context, Frame}
  alias Anubis.Server.Handlers.Tools
  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug
  alias Anubis.Server.Transport.StreamableHTTP.StatelessBinding
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
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

    request = %{
      "method" => "tools/call",
      "params" => %{"name" => "list_sites", "arguments" => %{}}
    }

    assert {:reply, %{"content" => [%{"text" => text}]}, returned} =
             Server.handle_request(request, frame)

    refute Map.has_key?(returned.assigns, :mcp_request)
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
    record_requests()

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

    conn = sdk_conn(body)
    context = %{auth: %{sub: user.id}, assigns: %{}, req_headers: conn.req_headers}
    response = StatelessBinding.call(conn, "2026-07-28", context, AnubisPlug.init(server: Server))

    assert %{"result" => %{"content" => [%{"text" => text}]}} = Jason.decode!(response.resp_body)
    assert Jason.decode!(text) == %{"sites" => [%{"id" => site.id, "label" => "owned.example"}]}

    record_requests()
    body = put_in(body, ["params", "name"], "wp_read_post")
    body = put_in(body, ["params", "arguments"], %{"site_id" => Ecto.UUID.generate()})

    conn = sdk_conn(body)
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

    assert Server.supported_input?(
             put_in(base, ["properties", "settings"], %{
               "type" => "object",
               "properties" => %{},
               "minProperties" => 1
             })
           )

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

  @tag :wordpress_runtime
  @tag skip: System.get_env("FRONTMAN_WP_RUNTIME_URL") == nil
  test "SDK discovers the connection after the first concurrent batch" do
    url = System.fetch_env!("FRONTMAN_WP_RUNTIME_URL")
    password = File.read!(System.fetch_env!("FRONTMAN_WP_RUNTIME_PASSWORD"))
    user = AccountsFixtures.user_fixture()
    previous_env = Application.get_env(:frontman_server, :env)
    Application.put_env(:frontman_server, :env, :dev)

    :public_key.cacerts_clear()

    :ok =
      :public_key.cacerts_load(String.to_charlist(System.fetch_env!("FRONTMAN_WP_RUNTIME_CA")))

    on_exit(fn ->
      if previous_env,
        do: Application.put_env(:frontman_server, :env, previous_env),
        else: Application.delete_env(:frontman_server, :env)

      :public_key.cacerts_clear()
    end)

    auth = embedded_client_auth(user)
    status_path = ~p"/api/wordpress/connections/status?#{%{catalog_url: url}}"

    assert json_response(bearer_get(build_conn(), auth, status_path), 200) == %{
             "connected" => false
           }

    response =
      bearer_post(build_conn(), auth, ~p"/api/wordpress/connections", %{
        catalog_url: url,
        call_url: url,
        username: "admin",
        password: password
      })

    assert %{"id" => created_site_id} = json_response(response, 200)

    assert json_response(bearer_get(build_conn(), auth, status_path), 200) == %{
             "connected" => true
           }

    for _ <- 1..32 do
      %Connection{user_id: user.id}
      |> Connection.changeset(%{
        catalog_url: url,
        call_url: url,
        username: "admin",
        password: password
      })
      |> Repo.insert!()
    end

    frame = %Frame{context: %Context{auth: %{sub: user.id}}}

    assert {:reply, %{"tools" => tools}, _} =
             Server.handle_request(%{"method" => "tools/list"}, frame)

    sites = WordPress.list_sites(Scope.for_user(user))
    assert Enum.any?(sites, &(&1.id == created_site_id))
    site_id = sites |> List.last() |> Map.fetch!(:id)
    assert {:ok, %{"tools" => catalog}} = WordPress.catalog(Scope.for_user(user), site_id, 5_000)
    expected = catalog |> Enum.map(& &1["name"]) |> MapSet.new()
    actual = tools |> Enum.map(& &1.name) |> MapSet.new() |> MapSet.delete("list_sites")
    assert MapSet.difference(expected, actual) == MapSet.new()
    assert MapSet.difference(actual, expected) == MapSet.new()

    if System.get_env("FRONTMAN_WP_EXPECT_WOO") == "1" do
      assert MapSet.member?(expected, "wc_create_product")
    end

    tool = Enum.find(tools, &(&1.name == "wp_read_post"))

    assert {:ok, _} =
             tool.validate_input.(%{
               "site_id" => site_id
             })
  end

  test "catalog union preserves provenance and rejects conflicts" do
    schema = %{"type" => "object", "properties" => %{"id" => %{"type" => "integer"}}}
    site = Ecto.UUID.generate()
    first = %{"name" => "tool", "inputSchema" => schema}
    other = Ecto.UUID.generate()
    unsupported = Map.put(first, "outputSchema", %{"type" => "object"})
    conflict = Map.put(first, "inputSchema", %{"type" => "object"})
    reserved = %{"name" => "list_sites", "inputSchema" => schema}

    tools =
      Server.catalog_tools([{site, first}, {other, first}, {other, reserved}], ["list_sites"])

    assert [tool] = tools
    assert tool.input_schema["required"] == ["site_id"]
    assert tool.input_schema["properties"]["id"] == %{"type" => "integer"}

    assert {:ok, %{"site_id" => ^site, "id" => 1}} =
             tool.validate_input.(%{"site_id" => site, "id" => 1})

    assert {:error, _} = tool.validate_input.(%{"site_id" => Ecto.UUID.generate()})

    assert Server.catalog_tools([{other, unsupported}], []) == []
    assert Server.catalog_tools([{other, Map.put(first, "outputSchema", nil)}], []) == []

    refute Enum.any?(
             Server.catalog_tools([{site, first}, {other, conflict}], []),
             &(&1.name == first["name"])
           )
  end

  def record_request(_event, _measurements, %{request: request}, test) do
    send(test, {:outbound, request.host})
  end

  defp record_requests do
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(handler, [:finch, :request, :start], &__MODULE__.record_request/4, self())

    on_exit(fn -> :telemetry.detach(handler) end)
  end

  defp sdk_conn(body) do
    Plug.Test.conn(:post, "/mcp", Jason.encode!(body))
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> Plug.Conn.put_req_header("mcp-protocol-version", "2026-07-28")
    |> Plug.Conn.put_req_header("mcp-method", body["method"])
    |> Plug.Conn.put_req_header("mcp-name", body["params"]["name"])
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
