defmodule FrontmanServerWeb.PlayGithub.SandboxProxyTest do
  use FrontmanServerWeb.ConnCase, async: false

  alias FrontmanServerWeb.PlayGithub.SandboxProxy.Daytona, as: TargetPolicy
  alias FrontmanServerWeb.PlayGithub.SandboxProxyPlug

  setup do
    previous_playgithub = Application.get_env(:frontman_server, :playgithub)
    TargetPolicy.clear_preview_link_cache()

    playgithub_config = previous_playgithub || []

    sandbox_proxy_config =
      playgithub_config
      |> Keyword.get(:sandbox_proxy, [])
      |> Keyword.merge(
        req_options: [plug: {Req.Test, :sandbox_proxy}],
        target_hosts: ["localhost", "daytonaproxy01.eu"],
        target_schemes: ["http", "https"]
      )

    Application.put_env(
      :frontman_server,
      :playgithub,
      playgithub_config
      |> Keyword.put(:hosts, ["www.example.com"])
      |> Keyword.put(:sandbox_proxy, sandbox_proxy_config)
    )

    on_exit(fn ->
      TargetPolicy.clear_preview_link_cache()
      restore_env(:playgithub, previous_playgithub)
    end)

    :ok
  end

  test "proxies a Daytona URL from the url query parameter", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/frontman/"
      assert conn.query_string == "debug=1"
      assert Plug.Conn.get_req_header(conn, "accept-encoding") == []
      assert Plug.Conn.get_req_header(conn, "authorization") == []
      assert Plug.Conn.get_req_header(conn, "cookie") == []
      assert Plug.Conn.get_req_header(conn, "x-daytona-skip-preview-warning") == ["true"]

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, "<html>Frontman</html>")
    end)

    target_url = URI.encode_www_form("http://localhost/frontman/")

    conn =
      conn
      |> put_req_header("accept-encoding", "gzip, br")
      |> put_req_header("authorization", "Bearer frontman-token")
      |> put_req_header("cookie", "frontman_session=secret")
      |> get("/sandbox?url=#{target_url}&debug=1")

    assert response(conn, 200) == "<html>Frontman</html>"
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
  end

  test "passes through requests on non-proxy hosts", %{conn: conn} do
    put_playgithub_hosts(["playgithub.frontman.local"])

    conn =
      conn
      |> put_request_host("frontman.local")
      |> SandboxProxyPlug.call([])

    assert conn.state == :unset
    refute conn.halted
  end

  test "proxies requests on configured proxy hosts", %{conn: conn} do
    put_playgithub_hosts(["playgithub.frontman.local"])

    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/frontman/"

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, "<html>Proxy host</html>")
    end)

    target_url = URI.encode_www_form("http://localhost/frontman/")

    conn =
      conn
      |> put_request_host("playgithub.frontman.local")
      |> get("/sandbox?url=#{target_url}")

    assert response(conn, 200) == "<html>Proxy host</html>"
  end

  test "proxies host-scoped sandbox IDs through Daytona preview links", %{conn: conn} do
    put_playgithub_hosts(["playgithub.frontman.local"])
    expect_daytona_preview_link("sandbox-123", 4321)

    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.host == "localhost"
      assert conn.request_path == "/frontman/"
      assert conn.query_string == "debug=1"
      assert Plug.Conn.get_req_header(conn, "x-daytona-preview-token") == ["preview-token"]

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, "<html>Host scoped proxy</html>")
    end)

    conn =
      conn
      |> put_request_host("sandbox-123-4321.playgithub.frontman.local")
      |> get("/frontman/?debug=1")

    assert response(conn, 200) == "<html>Host scoped proxy</html>"
  end

  test "caches host-scoped Daytona preview links for repeated sandbox requests", %{conn: conn} do
    put_playgithub_hosts(["playgithub.frontman.local"])
    expect_daytona_preview_link("sandbox-123", 4321)

    test_pid = self()

    Req.Test.stub(:sandbox_proxy, fn conn ->
      send(
        test_pid,
        {:proxied_request, conn.request_path,
         Plug.Conn.get_req_header(conn, "x-daytona-preview-token")}
      )

      Plug.Conn.send_resp(conn, 200, "ok")
    end)

    conn =
      conn
      |> put_request_host("sandbox-123-4321.playgithub.frontman.local")
      |> get("/frontman/")

    assert response(conn, 200) == "ok"

    conn =
      conn
      |> recycle()
      |> put_request_host("sandbox-123-4321.playgithub.frontman.local")
      |> get("/@vite/client")

    assert response(conn, 200) == "ok"
    assert_received {:proxied_request, "/frontman/", ["preview-token"]}
    assert_received {:proxied_request, "/@vite/client", ["preview-token"]}
  end

  test "rewrites runtime responses to host-scoped sandbox proxy URLs", %{conn: conn} do
    put_playgithub_hosts(["playgithub.frontman.local"])
    expect_daytona_preview_link("sandbox-123", 4321)

    Req.Test.stub(:sandbox_proxy, fn conn ->
      body = ~s(<span id="frontman-entrypoint-url" hidden>http://localhost/</span>)

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, body)
    end)

    conn =
      conn
      |> put_req_header("x-forwarded-proto", "https")
      |> put_req_header("x-forwarded-port", "443")
      |> put_request_host("sandbox-123-4321.playgithub.frontman.local")
      |> get("/frontman/")

    assert response(conn, 200) =~
             ~s(<span id="frontman-entrypoint-url" hidden>https://sandbox-123-4321.playgithub.frontman.local</span>)
  end

  test "rewrites Frontman iframe entrypoint through the sandbox proxy", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/frontman/"

      body = """
      <html>
        <span id="frontman-entrypoint-url" hidden>http://localhost/</span>
      </html>
      """

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, body)
    end)

    target_url = URI.encode_www_form("http://localhost")
    conn = get(conn, "/sandbox/frontman/?url=#{target_url}")

    assert response(conn, 200) =~
             ~s(<span id="frontman-entrypoint-url" hidden>http://www.example.com/sandbox?url=http%3A%2F%2Flocalhost</span>)
  end

  test "proxies nested sandbox paths against the provided base URL", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/frontman/tools"

      Req.Test.json(conn, %{"tools" => []})
    end)

    target_url = URI.encode_www_form("http://localhost")
    conn = get(conn, "/sandbox/frontman/tools?url=#{target_url}")

    assert json_response(conn, 200) == %{"tools" => []}
  end

  test "proxies root-relative Frontman tool requests using the sandbox referrer", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/frontman/tools"

      Req.Test.json(conn, %{"tools" => []})
    end)

    referrer_url =
      "https://frontman.local:4000/sandbox/frontman/?url=#{URI.encode_www_form("http://localhost")}"

    conn =
      conn
      |> put_req_header("referer", referrer_url)
      |> get("/frontman/tools")

    assert json_response(conn, 200) == %{"tools" => []}
  end

  test "does not double-prefix root-relative tool paths when referrer url includes frontman", %{
    conn: conn
  } do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/frontman/tools"

      Req.Test.json(conn, %{"tools" => []})
    end)

    referrer_url =
      "https://frontman.local:4000/sandbox?url=#{URI.encode_www_form("http://localhost/frontman/")}"

    conn =
      conn
      |> put_req_header("referer", referrer_url)
      |> get("/frontman/tools")

    assert json_response(conn, 200) == %{"tools" => []}
  end

  test "proxies same-origin iframe navigation using the sandbox referrer", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/blog/"
      assert conn.query_string == "page=1"

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, "<html>Blog</html>")
    end)

    referrer_url =
      "https://frontman.local:4000/sandbox?url=#{URI.encode_www_form("http://localhost")}"

    conn =
      conn
      |> put_req_header("referer", referrer_url)
      |> get("/blog/?page=1")

    assert response(conn, 200) == "<html>Blog</html>"
  end

  test "preserves raw query flags for referred iframe asset requests", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/src/components/ui/NavigationBar.astro"
      assert conn.query_string == "astro&type=style&index=0&lang.css"

      conn
      |> Plug.Conn.put_resp_content_type("text/javascript")
      |> Plug.Conn.send_resp(200, "export default {}")
    end)

    referrer_url =
      "https://frontman.local:4000/sandbox?url=#{URI.encode_www_form("http://localhost")}"

    conn =
      conn
      |> put_req_header("referer", referrer_url)
      |> get("/src/components/ui/NavigationBar.astro?astro&type=style&index=0&lang.css")

    assert response(conn, 200) == "export default {}"
  end

  test "preserves Vite special path characters for referred iframe assets", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"

      assert conn.request_path ==
               "/@fs/root/frontman/node_modules/@fontsource-variable/inter/index.css"

      conn
      |> Plug.Conn.put_resp_content_type("text/javascript")
      |> Plug.Conn.send_resp(200, "export default {}")
    end)

    referrer_url =
      "https://frontman.local:4000/sandbox?url=#{URI.encode_www_form("http://localhost")}"

    conn =
      conn
      |> put_req_header("referer", referrer_url)
      |> get("/@fs/root/frontman/node_modules/@fontsource-variable/inter/index.css")

    assert response(conn, 200) == "export default {}"
  end

  test "proxies nested Vite asset imports using the remembered sandbox source", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"

      assert conn.request_path ==
               "/@fs/root/frontman/node_modules/vite/dist/client/env.mjs"

      conn
      |> Plug.Conn.put_resp_content_type("text/javascript")
      |> Plug.Conn.send_resp(200, "export default {}")
    end)

    conn =
      conn
      |> put_req_header(
        "cookie",
        source_url_cookie_header("http://localhost")
      )
      |> get("/@fs/root/frontman/node_modules/vite/dist/client/env.mjs")

    assert response(conn, 200) == "export default {}"
  end

  test "stores the sandbox origin for nested Vite asset imports", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/frontman/"

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, "<html>Frontman</html>")
    end)

    target_url = URI.encode_www_form("http://localhost/frontman/")
    conn = get(conn, "/sandbox?url=#{target_url}")

    assert [cookie] = get_resp_header(conn, "set-cookie")
    assert cookie =~ "_frontman_sandbox_source_url=aHR0cDovL2xvY2FsaG9zdA"
    assert cookie =~ "HttpOnly"
  end

  test "rewrites proxied Vite client HMR hosts to the proxy host", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/@vite/client"

      body = """
      const serverHost = "localhost:4321/";
      const socketHost = `${null || importMetaUrl.hostname}:${hmrPort || importMetaUrl.port}${"/"}`;
      const directSocketHost = "localhost:4321/";
      """

      conn
      |> Plug.Conn.put_resp_content_type("text/javascript")
      |> Plug.Conn.send_resp(200, body)
    end)

    source_url = "https://4321-test.daytonaproxy01.eu"

    conn =
      conn
      |> put_req_header("cookie", source_url_cookie_header(source_url))
      |> get("/@vite/client")

    assert response(conn, 200) =~ ~s(const serverHost = "www.example.com/";)
    assert response(conn, 200) =~ ~s(const socketHost = "www.example.com/";)
    assert response(conn, 200) =~ ~s(const directSocketHost = "www.example.com/";)
  end

  test "upgrades Vite HMR websocket requests through the sandbox websocket proxy", %{conn: conn} do
    conn =
      conn
      |> put_test_host_header()
      |> put_req_header("authorization", "Bearer frontman-token")
      |> put_req_header("connection", "Upgrade")
      |> put_req_header("upgrade", "websocket")
      |> put_req_header("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
      |> put_req_header("sec-websocket-version", "13")
      |> put_req_header("sec-websocket-protocol", "vite-hmr")
      |> put_req_header("cookie", source_url_cookie_header("http://localhost"))
      |> get("/?token=dev-token")

    assert conn.state == :upgraded
    assert get_resp_header(conn, "sec-websocket-protocol") == ["vite-hmr"]

    assert_received {_ref, :upgrade,
                     {:websocket,
                      {FrontmanServerWeb.PlayGithub.SandboxProxy.WebSocket, state, opts}}}

    assert state.target_url == "ws://localhost/?token=dev-token"
    assert {"sec-websocket-protocol", "vite-hmr"} in state.upstream_headers
    assert {"x-daytona-skip-preview-warning", "true"} in state.upstream_headers
    refute Enum.any?(state.upstream_headers, fn {name, _value} -> name == "authorization" end)
    refute Enum.any?(state.upstream_headers, fn {name, _value} -> name == "cookie" end)
    assert opts[:timeout] == 60_000
  end

  test "upgrades Vite HMR websocket requests to wss for https sandboxes", %{conn: conn} do
    conn =
      conn
      |> put_test_host_header()
      |> put_req_header("connection", "keep-alive, Upgrade")
      |> put_req_header("upgrade", "websocket")
      |> put_req_header("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
      |> put_req_header("sec-websocket-version", "13")
      |> put_req_header("sec-websocket-protocol", "vite-hmr")
      |> put_req_header("cookie", source_url_cookie_header("https://4321-test.daytonaproxy01.eu"))
      |> get("/?token=dev-token")

    assert conn.state == :upgraded

    assert_received {_ref, :upgrade,
                     {:websocket,
                      {FrontmanServerWeb.PlayGithub.SandboxProxy.WebSocket, state, _opts}}}

    assert state.target_url == "wss://4321-test.daytonaproxy01.eu/?token=dev-token"
  end

  test "forwards raw request bodies", %{conn: conn} do
    Req.Test.stub(:sandbox_proxy, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/frontman/tools/call"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert body == ~s({"name":"get_client_pages"})

      Req.Test.json(conn, %{"ok" => true})
    end)

    target_url = URI.encode_www_form("http://localhost")

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/sandbox/frontman/tools/call?url=#{target_url}", ~s({"name":"get_client_pages"}))

    assert json_response(conn, 200) == %{"ok" => true}
  end

  test "rejects missing url query parameter", %{conn: conn} do
    conn = get(conn, "/sandbox")

    assert json_response(conn, 400) == %{"error" => "Missing url query parameter"}
  end

  test "rejects unsupported hosts", %{conn: conn} do
    target_url = URI.encode_www_form("https://example.com/frontman/")
    conn = get(conn, "/sandbox?url=#{target_url}")

    assert json_response(conn, 400) == %{"error" => "Unsupported Daytona host"}
  end

  test "answers CORS preflight requests", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "https://app.frontman.sh")
      |> put_req_header("access-control-request-headers", "content-type, x-test")
      |> options("/sandbox?url=#{URI.encode_www_form("http://localhost/frontman/")}")

    assert response(conn, 204) == ""
    assert get_resp_header(conn, "access-control-allow-origin") == ["https://app.frontman.sh"]
    assert get_resp_header(conn, "access-control-allow-headers") == ["content-type, x-test"]
  end

  test "redirects Daytona warning acceptance back through the sandbox proxy", %{conn: conn} do
    redirect_url = "http://localhost/frontman/"

    conn =
      post(
        conn,
        "/accept-daytona-preview-warning?redirect=#{URI.encode_www_form(redirect_url)}"
      )

    assert redirected_to(conn) == "/sandbox?url=http%3A%2F%2Flocalhost%2Ffrontman%2F"
  end

  defp restore_env(key, nil), do: Application.delete_env(:frontman_server, key)
  defp restore_env(key, value), do: Application.put_env(:frontman_server, key, value)

  defp put_playgithub_hosts(hosts) do
    playgithub_config = Application.get_env(:frontman_server, :playgithub, [])

    Application.put_env(
      :frontman_server,
      :playgithub,
      Keyword.put(playgithub_config, :hosts, hosts)
    )
  end

  defp expect_daytona_preview_link(sandbox_id, port) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_id}/ports/#{port}/preview-url"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      Req.Test.json(conn, %{"token" => "preview-token", "url" => "http://localhost"})
    end)
  end

  defp source_url_cookie_header(raw_url) do
    encoded_url = Base.url_encode64(raw_url, padding: false)
    "_frontman_sandbox_source_url=#{encoded_url}"
  end

  defp put_request_host(conn, host) do
    %{conn | host: host, req_headers: [{"host", host} | conn.req_headers]}
  end

  defp put_test_host_header(conn) do
    %{conn | req_headers: [{"host", conn.host} | conn.req_headers]}
  end
end
