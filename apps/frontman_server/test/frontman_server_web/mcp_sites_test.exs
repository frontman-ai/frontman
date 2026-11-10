defmodule FrontmanServerWeb.MCPSitesTest do
  use FrontmanServerWeb.ConnCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  alias Anubis.Server.{Context, Frame}
  alias Anubis.Server.Handlers.Tools
  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug
  alias Anubis.Server.Transport.StreamableHTTP.StatelessBinding
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.BillingFixtures
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.Test.Fixtures.Tasks, as: TasksFixtures
  alias FrontmanServer.WordPress
  alias FrontmanServer.WordPress.Connection
  alias FrontmanServer.Workers.SyncResendContact
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
    assert_inactive(owner)
  end

  test "empty accounts return no sites and missing subjects fail closed" do
    user = AccountsFixtures.user_fixture()
    request = %{"params" => %{"name" => "list_sites", "arguments" => %{}}}
    frame = %Frame{context: %Context{auth: %{sub: user.id}}}

    assert {:reply, %{"tools" => [%{"name" => "list_sites"}]}, _} =
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

  test "HTTP discovery declares read-only OAuth-protected site discovery for empty accounts" do
    user = AccountsFixtures.user_fixture()

    assert %{"result" => %{"tools" => [tool]}} = sdk_request(user, "tools/list")
    assert tool["name"] == "list_sites"
    assert tool["inputSchema"] == %{"type" => "object", "properties" => %{}}

    assert tool["annotations"] == %{
             "readOnlyHint" => true,
             "destructiveHint" => false,
             "openWorldHint" => false,
             "idempotentHint" => true
           }

    assert_oauth(tool)
    assert_inactive(user)
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

    deadline = System.monotonic_time(:millisecond) + 1_000

    results =
      owner
      |> Scope.for_user()
      |> WordPress.stream_catalogs([foreign.id, owned.id], deadline)
      |> Enum.to_list()

    assert Enum.sort(results) ==
             Enum.sort([
               {:ok, {foreign.id, {:error, :connection_failed}}},
               {:ok, {owned.id, {:error, :connection_failed}}}
             ])

    refute_received {:outbound, _, _, "owner.invalid"}
    refute_received {:outbound, _, _, "foreign.invalid"}
    assert_inactive(owner)
  end

  test "stateless SDK binding parses and dispatches a request with verified claims" do
    user = AccountsFixtures.user_fixture()
    site = insert_site(user, "owned.example")

    assert %{"result" => %{"content" => [%{"text" => text}]}} =
             sdk_request(user, "tools/call", %{"name" => "list_sites", "arguments" => %{}})

    assert Jason.decode!(text) == %{"sites" => [%{"id" => site.id, "label" => "owned.example"}]}

    for arguments <- [%{}, %{"site_id" => Ecto.UUID.generate()}] do
      assert %{"error" => %{"code" => -32_602, "data" => %{"message" => message}}} =
               sdk_request(user, "tools/call", %{
                 "name" => "wp_read_post",
                 "arguments" => arguments
               })

      assert message =~ "Call list_sites"
      assert message =~ "site_id"
    end

    refute_received {:outbound, _, _, "owned.example"}
    assert_inactive(user)
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
  test "HTTP discovery preserves the full WordPress catalog beyond the first concurrent batch" do
    user = AccountsFixtures.user_fixture()
    connect_wordpress_runtime(user, 33)

    site_id = user |> Scope.for_user() |> WordPress.list_sites() |> List.last() |> Map.fetch!(:id)
    assert {:ok, %{"tools" => catalog}} = WordPress.catalog(Scope.for_user(user), site_id, 5_000)

    assert %{"result" => %{"tools" => tools}} =
             sdk_request(user, "tools/list", %{}, List.duplicate("GET", 33))

    expected = catalog |> Enum.map(& &1["name"]) |> MapSet.new()
    actual = tools |> Enum.map(& &1["name"]) |> MapSet.new() |> MapSet.delete("list_sites")
    assert actual == expected

    if System.get_env("FRONTMAN_WP_EXPECT_WOO") == "1" do
      assert MapSet.member?(expected, "wc_create_product")
    end

    by_name = Map.new(tools, &{&1["name"], &1})

    for remote <- catalog do
      tool = Map.fetch!(by_name, remote["name"])
      assert tool["description"] == remote["description"]
      assert tool["annotations"] == remote["annotations"]

      for hint <- ~w(readOnlyHint destructiveHint openWorldHint idempotentHint) do
        assert is_boolean(tool["annotations"][hint])
      end

      schema = remote["inputSchema"]

      assert tool["inputSchema"] ==
               schema
               |> Map.put(
                 "properties",
                 Map.put(Map.get(schema, "properties", %{}), "site_id", %{
                   "type" => "string",
                   "description" =>
                     "The connected site's id returned by list_sites. Call list_sites first; do not use a URL or WordPress post ID."
                 })
               )
               |> Map.put("required", ["site_id" | Map.get(schema, "required", [])])
    end

    Enum.each(tools, &assert_oauth/1)
    assert_inactive(user)

    assert %{"result" => %{"content" => [_ | _], "isError" => false}} =
             sdk_request(user, "tools/call", %{
               "name" => "wp_get_site_info",
               "arguments" => %{"site_id" => site_id}
             })

    assert %DateTime{} = first_use = Repo.reload!(user).first_message_at

    assert [%{args: args}] =
             all_enqueued(worker: SyncResendContact, args: %{user_id: user.id})

    assert args == %{"activation" => true, "user_id" => user.id}

    assert %{"result" => %{"isError" => false}} =
             sdk_request(user, "tools/call", %{
               "name" => "wp_get_site_info",
               "arguments" => %{"site_id" => site_id}
             })

    assert Repo.reload!(user).first_message_at == first_use
    assert [_] = all_enqueued(worker: SyncResendContact, args: %{user_id: user.id})

    submit_prompt(user)
    assert Repo.reload!(user).first_message_at == first_use
    assert [%{args: ^args}] = all_enqueued(worker: SyncResendContact, args: %{user_id: user.id})
  end

  @tag :wordpress_runtime
  @tag skip: System.get_env("FRONTMAN_WP_RUNTIME_URL") == nil
  test "remote tool errors do not activate" do
    user = AccountsFixtures.user_fixture()
    [site] = connect_wordpress_runtime(user, 1)

    assert %{"result" => %{"isError" => true}} =
             sdk_request(user, "tools/call", %{
               "name" => "wp_read_post",
               "arguments" => %{"site_id" => site.id, "id" => 2_147_483_647}
             })

    assert_inactive(user)

    submit_prompt(user)
    assert %DateTime{} = first_use = Repo.reload!(user).first_message_at
    assert [%{args: args}] = all_enqueued(worker: SyncResendContact, args: %{user_id: user.id})
    assert args == %{"activation" => true, "user_id" => user.id}

    assert %{"result" => %{"isError" => false}} =
             sdk_request(user, "tools/call", %{
               "name" => "wp_get_site_info",
               "arguments" => %{"site_id" => site.id}
             })

    assert Repo.reload!(user).first_message_at == first_use
    assert [%{args: ^args}] = all_enqueued(worker: SyncResendContact, args: %{user_id: user.id})
  end

  @tag :wordpress_runtime
  @tag skip: System.get_env("FRONTMAN_WP_RUNTIME_URL") == nil
  test "HTTP discovery fails completely during outages while selected-site calls keep working" do
    user = AccountsFixtures.user_fixture()
    [selected, offline] = connect_wordpress_runtime(user, 2)
    url = selected.catalog_url
    invalid_url = String.replace(url, "/frontman/v1/tools", "/wp/v2/types")
    params = %{"name" => "wp_read_post", "arguments" => %{"site_id" => selected.id, "id" => 1}}

    assert %{"result" => %{"tools" => tools}} = sdk_request(user, "tools/list")
    expected = MapSet.new(tools, & &1["name"])

    assert %{"result" => %{"content" => [%{"text" => before}], "isError" => false}} =
             sdk_request(user, "tools/call", params)

    assert %{"id" => 1} = Jason.decode!(before)

    for catalog_url <- [invalid_url, "https://offline.invalid/tools"] do
      offline
      |> Repo.reload!()
      |> Connection.changeset(%{catalog_url: catalog_url})
      |> Repo.update!()

      response = sdk_request(user, "tools/list")

      assert %{"error" => %{"code" => -32_000, "message" => "WordPress catalog unavailable"}} =
               response

      refute Map.has_key?(response, "result")

      assert %{"result" => %{"content" => [%{"text" => ^before}], "isError" => false}} =
               sdk_request(user, "tools/call", params, ["GET", "POST"])
    end

    invalid =
      params
      |> Map.put("name", "wp_update_post")
      |> put_in(["arguments", "content"], 123)

    assert %{"error" => _} = sdk_request(user, "tools/call", invalid, ["GET", "POST"])

    assert %{"result" => %{"content" => [%{"text" => ^before}], "isError" => false}} =
             sdk_request(user, "tools/call", params, ["GET", "POST"])

    offline |> Repo.reload!() |> Connection.changeset(%{catalog_url: url}) |> Repo.update!()
    assert %{"result" => %{"tools" => recovered}} = sdk_request(user, "tools/list")
    assert MapSet.new(recovered, & &1["name"]) == expected
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

  test "SDK pagination preserves descriptor metadata but replaces upstream OAuth declarations" do
    site = Ecto.UUID.generate()

    remote = %{
      "name" => "wp_read_post",
      "title" => "Read post",
      "description" => "Read stored post content.",
      "inputSchema" => %{"type" => "object", "properties" => %{}},
      "annotations" => %{
        "readOnlyHint" => true,
        "destructiveHint" => false,
        "openWorldHint" => false,
        "idempotentHint" => true
      },
      "icons" => [%{"src" => "https://example.com/icon.png"}],
      "securitySchemes" => [%{"type" => "noauth"}],
      "_meta" => %{
        "securitySchemes" => [%{"type" => "noauth"}],
        "ai.frontman/tool-metadata" => %{"access" => "read"}
      }
    }

    assert [tool] = Server.catalog_tools([{site, remote}], [])
    user = AccountsFixtures.user_fixture()

    frame = %Frame{
      context: %Context{auth: %{sub: user.id}},
      tools: %{tool.name => tool},
      pagination_limit: 1
    }

    assert {:reply, %{"tools" => [first], "nextCursor" => cursor}, returned} =
             Server.handle_request(%{"method" => "tools/list"}, frame)

    assert first["name"] == "list_sites"
    assert_oauth(first)
    refute Map.has_key?(returned.assigns, :mcp_catalog)

    assert {:reply, page, _} =
             Server.handle_request(
               %{"method" => "tools/list", "params" => %{"cursor" => cursor}},
               frame
             )

    assert %{"tools" => [forwarded]} = page |> JSON.encode!() |> Jason.decode!()
    refute Map.has_key?(page, "nextCursor")
    assert_oauth(forwarded)
    assert forwarded["_meta"]["ai.frontman/tool-metadata"] == %{"access" => "read"}

    for key <- ~w(name title description annotations icons) do
      assert forwarded[key] == remote[key]
    end

    assert forwarded["inputSchema"] == tool.input_schema
  end

  def record_request([:anubis_mcp, :server, :request], _, %{id: id}, {test, id})
      when is_binary(id),
      do: Process.put(:"$callers", [test])

  def record_request([:finch, :request, :start], _, %{request: request}, {test, id}) do
    if test in [self() | Process.get(:"$callers", [])],
      do: send(test, {:outbound, id, request.method, request.host})
  end

  def record_request(
        [:finch, :request, :stop],
        _,
        %{request: request, result: {:ok, _}},
        {test, id}
      ) do
    if test in [self() | Process.get(:"$callers", [])],
      do: send(test, {:completed, id, request.method, request.host})
  end

  def record_request(_, _, _, _), do: :ok

  defp record_requests(id \\ nil) do
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach_many(
        handler,
        [
          [:finch, :request, :start],
          [:finch, :request, :stop],
          [:anubis_mcp, :server, :request]
        ],
        &__MODULE__.record_request/4,
        {self(), id}
      )

    on_exit(fn -> :telemetry.detach(handler) end)
    handler
  end

  defp sdk_conn(body) do
    Plug.Test.conn(:post, "/mcp", Jason.encode!(body))
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> Plug.Conn.put_req_header("mcp-protocol-version", "2026-07-28")
    |> Plug.Conn.put_req_header("mcp-method", body["method"])
    |> then(fn conn ->
      case body["params"]["name"] do
        nil -> conn
        name -> Plug.Conn.put_req_header(conn, "mcp-name", name)
      end
    end)
  end

  defp sdk_request(user, method, params \\ %{}, expected_methods \\ nil) do
    body = %{
      "jsonrpc" => "2.0",
      "id" => Ecto.UUID.generate(),
      "method" => method,
      "params" =>
        Map.put(params, "_meta", %{
          "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
          "io.modelcontextprotocol/clientCapabilities" => %{},
          "io.modelcontextprotocol/clientInfo" => %{"name" => "test", "version" => "1"}
        })
    }

    handler = record_requests(body["id"])
    conn = sdk_conn(body)
    context = %{auth: %{sub: user.id}, assigns: %{}, req_headers: conn.req_headers}

    try do
      response =
        StatelessBinding.call(conn, "2026-07-28", context, AnubisPlug.init(server: Server))

      assert response.status == 200

      if expected_methods do
        id = body["id"]
        host = System.fetch_env!("FRONTMAN_WP_RUNTIME_URL") |> URI.parse() |> Map.fetch!(:host)

        for method <- expected_methods do
          assert_received {:outbound, ^id, ^method, ^host}
          assert_received {:completed, ^id, ^method, ^host}
        end

        refute_received {:outbound, ^id, _, _}
        refute_received {:completed, ^id, _, _}
      end

      Jason.decode!(response.resp_body)
    after
      :telemetry.detach(handler)
    end
  end

  defp assert_oauth(tool) do
    assert tool["securitySchemes"] == [%{"type" => "oauth2", "scopes" => []}]
    assert tool["_meta"]["securitySchemes"] == tool["securitySchemes"]
  end

  defp assert_inactive(user) do
    assert is_nil(Repo.reload!(user).first_message_at)
    assert all_enqueued(worker: SyncResendContact, args: %{user_id: user.id}) == []
  end

  defp submit_prompt(user) do
    scope = Scope.for_user(user)
    BillingFixtures.allow_access_for_scope_fixture(scope)
    task = TasksFixtures.task_fixture(scope)

    assert {:ok, _} =
             Tasks.submit_user_message(scope, %{
               task_id: task.id,
               message_id: Ecto.UUID.generate(),
               message: TasksFixtures.user_content("hello"),
               model: "openrouter:openai/gpt-5.5",
               agent_id: "test-frontman"
             })
  end

  defp connect_wordpress_runtime(user, count) when count > 0 do
    url = System.fetch_env!("FRONTMAN_WP_RUNTIME_URL")
    password = File.read!(System.fetch_env!("FRONTMAN_WP_RUNTIME_PASSWORD"))

    for _ <- 1..count do
      %Connection{user_id: user.id}
      |> Connection.changeset(%{
        catalog_url: url,
        call_url: url <> "/call",
        username: "admin",
        password: password
      })
      |> Repo.insert!()
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
