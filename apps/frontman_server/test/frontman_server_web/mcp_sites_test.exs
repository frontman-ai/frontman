defmodule FrontmanServerWeb.MCPSitesTest do
  use FrontmanServerWeb.ConnCase, async: true

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

    refute Map.has_key?(returned.assigns, :mcp_catalog)
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

    assert {:reply, %{"tools" => [%{name: "list_sites"}]}, _} =
             Server.handle_request(%{"method" => "tools/list"}, frame)

    assert {:reply, %{"content" => [%{"text" => text}]} = result, _} =
             Tools.handle_call(request, frame, Server)

    refute result["isError"]

    assert %{
             "sites" => [],
             "status" => "connection_required",
             "connection_url" => "https://resource.example/wordpress/connect",
             "explanation" => explanation,
             "next_steps" => steps
           } = Jason.decode!(text)

    assert is_binary(explanation) and byte_size(explanation) > 0
    assert is_list(steps) and steps != []
    assert Enum.all?(steps, &is_binary/1)

    site = insert_site(user, "connected.example")

    assert {:reply, %{"content" => [%{"text" => text}]}, _} =
             Tools.handle_call(request, frame, Server)

    assert Jason.decode!(text) == %{
             "sites" => [%{"id" => site.id, "label" => "connected.example"}]
           }

    assert {:error, _, _} = Tools.handle_call(request, %Frame{}, Server)
  end

  test "parsed SDK calls reject absent, malformed and foreign selectors before discovery" do
    owner = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    owned = insert_site(owner, "owner.invalid")
    foreign = insert_site(other, "foreign.invalid")
    Repo.delete!(owned)

    frame = %Frame{
      context: %Context{auth: %{sub: owner.id}},
      assigns: %{mcp_catalog: :original}
    }

    record_requests()

    for arguments <- [
          %{},
          %{"site_id" => nil},
          %{"site_id" => "bad"},
          %{"site_id" => "https://owner.invalid"},
          %{"site_id" => foreign.id},
          %{"site_id" => owned.id}
        ] do
      request = %{
        "method" => "tools/call",
        "params" => %{"name" => "wp_read_post", "arguments" => arguments}
      }

      assert {:error, error, returned} = Server.handle_request(request, frame)
      assert error.code == -32_602

      assert error.data.message ==
               "Call list_sites and pass an accessible site's id as site_id. " <>
                 "If no sites are listed, connect a WordPress site first."

      assert returned.assigns.mcp_catalog == :original
    end

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
      "id" => Ecto.UUID.generate(),
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

    record_requests(body["id"])
    conn = sdk_conn(body)
    context = %{auth: %{sub: user.id}, assigns: %{}, req_headers: conn.req_headers}
    response = StatelessBinding.call(conn, "2026-07-28", context, AnubisPlug.init(server: Server))

    assert %{"result" => %{"content" => [%{"text" => text}]}} = Jason.decode!(response.resp_body)
    assert Jason.decode!(text) == %{"sites" => [%{"id" => site.id, "label" => "owned.example"}]}

    body = put_in(body, ["params", "name"], "wp_read_post")

    for arguments <- [%{}, %{"site_id" => Ecto.UUID.generate()}] do
      conn = sdk_conn(put_in(body, ["params", "arguments"], arguments))

      response =
        StatelessBinding.call(conn, "2026-07-28", context, AnubisPlug.init(server: Server))

      assert %{"error" => %{"code" => -32_602, "data" => %{"message" => message}}} =
               Jason.decode!(response.resp_body)

      assert message =~ "Call list_sites"
      assert message =~ "site_id"
    end

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
  test "SDK lists all sites but calls only the selected site" do
    url = System.fetch_env!("FRONTMAN_WP_RUNTIME_URL")
    password = File.read!(System.fetch_env!("FRONTMAN_WP_RUNTIME_PASSWORD"))
    user = AccountsFixtures.user_fixture()

    connections =
      for _ <- 1..33 do
        %Connection{user_id: user.id}
        |> Connection.changeset(%{
          catalog_url: url,
          call_url: String.replace_suffix(url, "/tools", "/tools/call"),
          username: "admin",
          password: password
        })
        |> Repo.insert!()
      end

    frame = %Frame{context: %Context{auth: %{sub: user.id}}}

    assert {:reply, %{"tools" => tools}, _} =
             Server.handle_request(%{"method" => "tools/list"}, frame)

    site_id = user |> Scope.for_user() |> WordPress.list_sites() |> List.last() |> Map.fetch!(:id)
    assert {:ok, %{"tools" => catalog}} = WordPress.catalog(Scope.for_user(user), site_id, 5_000)
    expected = catalog |> Enum.map(& &1["name"]) |> MapSet.new()
    actual = tools |> Enum.map(& &1.name) |> MapSet.new() |> MapSet.delete("list_sites")
    assert actual == expected

    if System.get_env("FRONTMAN_WP_EXPECT_WOO") == "1" do
      assert MapSet.member?(expected, "wc_create_product")
    end

    request = %{
      "method" => "tools/call",
      "params" => %{"name" => "wp_read_post", "arguments" => %{"site_id" => site_id, "id" => 1}}
    }

    assert {:reply, %{"content" => [%{"text" => before}], "isError" => false}, _} =
             Server.handle_request(request, frame)

    assert %{"id" => 1} = Jason.decode!(before)
    offline = Enum.find(connections, &(&1.id != site_id))

    body = %{
      "jsonrpc" => "2.0",
      "id" => Ecto.UUID.generate(),
      "method" => "tools/list",
      "params" => %{
        "_meta" => %{
          "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
          "io.modelcontextprotocol/clientCapabilities" => %{},
          "io.modelcontextprotocol/clientInfo" => %{"name" => "test", "version" => "1"}
        }
      }
    }

    invalid_url = String.replace(url, "/frontman/v1/tools", "/wp/v2/types")
    handler = {__MODULE__, body["id"]}

    :ok =
      :telemetry.attach(
        handler,
        [:anubis_mcp, :server, :request],
        &__MODULE__.record_request/4,
        {self(), body["id"]}
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    for catalog_url <- [invalid_url, "https://offline.invalid/tools"] do
      offline |> Connection.changeset(%{catalog_url: catalog_url}) |> Repo.update!()

      if catalog_url == invalid_url do
        assert {:ok, catalog} = WordPress.catalog(Scope.for_user(user), offline.id, 5_000)
        refute Map.has_key?(catalog, "tools")
      end

      conn = sdk_conn(body)
      context = %{auth: %{sub: user.id}, assigns: %{}, req_headers: conn.req_headers}

      response =
        StatelessBinding.call(conn, "2026-07-28", context, AnubisPlug.init(server: Server))

      assert %{"error" => %{"code" => -32_000, "message" => "WordPress catalog unavailable"}} =
               Jason.decode!(response.resp_body)

      refute Map.has_key?(Jason.decode!(response.resp_body), "result")
    end

    record_requests()

    assert {:reply, %{"content" => [%{"text" => ^before}], "isError" => false}, _} =
             Server.handle_request(request, frame)

    invalid = put_in(request, ["params", "name"], "wp_update_post")
    invalid = put_in(invalid, ["params", "arguments", "content"], 123)
    assert {:error, _, _} = Server.handle_request(invalid, frame)

    assert {:reply, %{"content" => [%{"text" => ^before}], "isError" => false}, _} =
             Server.handle_request(request, frame)

    host = URI.parse(url).host
    for _ <- 1..6, do: assert_received({:outbound, ^host})
    refute_received {:outbound, _}

    Connection
    |> Repo.get!(offline.id)
    |> Connection.changeset(%{catalog_url: url})
    |> Repo.update!()

    assert {:reply, %{"tools" => recovered}, _} =
             Server.handle_request(%{"method" => "tools/list"}, frame)

    assert recovered |> Enum.map(& &1.name) |> MapSet.new() |> MapSet.delete("list_sites") ==
             expected
  end

  @tag :wordpress_client
  @tag skip: System.get_env("FRONTMAN_WP_RUNTIME_URL") == nil
  @tag timeout: 180_000
  test "the real client approves, restores and changes WordPress access" do
    user = AccountsFixtures.user_fixture()

    %{scheme: scheme, host: host, port: port} =
      URI.parse(System.fetch_env!("FRONTMAN_WP_RUNTIME_URL"))

    origin = "#{scheme}://#{host}:#{port}"
    auth = embedded_client_auth(user, origin)

    server =
      start_supervised!(
        {Bandit,
         plug: {FrontmanServerWeb.WordPressRuntime, self()},
         scheme: :https,
         port: 0,
         ip: {127, 0, 0, 1},
         certfile: System.fetch_env!("FRONTMAN_WP_RUNTIME_CERT"),
         keyfile: System.fetch_env!("FRONTMAN_WP_RUNTIME_KEY")}
      )

    {:ok, {_, api_port}} = ThousandIsland.listener_info(server)
    api = "https://127.0.0.1:#{api_port}"

    assert {:error, %ArgumentError{}} =
             Req.get(api, plugins: [FrontmanServerWeb.WordPressRuntime])

    path = Path.join(System.fetch_env!("FRONTMAN_WP_RUNTIME_DIRECTORY"), "client.json")

    File.open!(path, [:write, :exclusive], fn file ->
      File.chmod!(path, 0o600)

      IO.write(file, Jason.encode!(%{origin: origin, api: api, token: auth.token}))
    end)

    assert {_, 0} =
             System.cmd(System.get_env("CONTAINER_RUNTIME", "docker"), [
               "exec",
               System.fetch_env!("FRONTMAN_WP_RUNTIME_CONTAINER"),
               "php",
               "/tmp/RunWordPressRuntimeTest.php",
               "client-setup"
             ])

    {output, status} =
      System.cmd("make", ["test", "TEST_FILTER=test/Client__WordPressBrowser.test.res.mjs"],
        cd: Path.expand("../../../../libs/client", __DIR__),
        env: [{"FRONTMAN_WP_CLIENT_API", api}],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert [%{id: id}] = WordPress.list_sites(Scope.for_user(user))
    assert {:ok, %{"tools" => [_ | _]}} = WordPress.catalog(Scope.for_user(user), id, 5_000)
  end

  test "catalog union augments inputs and rejects conflicts" do
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
    assert tool.input_schema["properties"]["site_id"]["description"] =~ "returned by list_sites"

    assert {:ok, %{"site_id" => ^site, "id" => 1}} =
             tool.validate_input.(%{"site_id" => site, "id" => 1})

    assert Server.catalog_tools([{other, unsupported}], []) == []
    assert Server.catalog_tools([{other, Map.put(first, "outputSchema", nil)}], []) == []

    refute Enum.any?(
             Server.catalog_tools([{site, first}, {other, conflict}], []),
             &(&1.name == first["name"])
           )
  end

  def record_request([:anubis_mcp, :server, :request], _, %{id: id}, {test, id})
      when is_binary(id),
      do: Process.put(:"$callers", [test])

  def record_request([:finch, :request, :start], _, %{request: request}, {test, _id}) do
    if test in [self() | Process.get(:"$callers", [])], do: send(test, {:outbound, request.host})
  end

  def record_request(_, _, _, _), do: :ok

  defp record_requests(id \\ nil) do
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach_many(
        handler,
        [[:finch, :request, :start], [:anubis_mcp, :server, :request]],
        &__MODULE__.record_request/4,
        {self(), id}
      )

    on_exit(fn -> :telemetry.detach(handler) end)
  end

  defp sdk_conn(body) do
    conn =
      Plug.Test.conn(:post, "/mcp", Jason.encode!(body))
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("mcp-protocol-version", "2026-07-28")
      |> Plug.Conn.put_req_header("mcp-method", body["method"])

    case body["params"]["name"] do
      nil -> conn
      name -> Plug.Conn.put_req_header(conn, "mcp-name", name)
    end
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
