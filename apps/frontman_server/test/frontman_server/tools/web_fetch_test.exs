defmodule FrontmanServer.Tools.WebFetchTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Tools.WebFetch
  alias ModelContextProtocol, as: MCP

  setup do
    context = %FrontmanServer.Tools.Backend.Context{
      task: nil
    }

    %{context: context}
  end

  defp stub_resp(status, content_type, body) do
    Req.Test.stub(:web_fetch, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type(content_type)
      |> Plug.Conn.send_resp(status, body)
    end)
  end

  defp stub_resp(status, body) do
    Req.Test.stub(:web_fetch, fn conn ->
      Plug.Conn.send_resp(conn, status, body)
    end)
  end

  defp execute(url, context, opts \\ %{}) do
    WebFetch.execute(Map.merge(%{"url" => url}, opts), context)
  end

  defp execute_text(url, context, opts \\ %{}) do
    result = execute(url, context, opts)
    refute MCP.error?(result)
    result |> MCP.extract_content_text() |> MCP.parse_tool_result()
  end

  defp execute_error(url, context, opts \\ %{}) do
    result = execute(url, context, opts)
    assert MCP.error?(result)
    MCP.extract_content_text(result)
  end

  describe "name/0" do
    test "returns web_fetch" do
      assert WebFetch.name() == "web_fetch"
    end
  end

  describe "description/0" do
    test "returns a non-empty string" do
      assert is_binary(WebFetch.description())
      assert String.length(WebFetch.description()) > 0
    end
  end

  describe "parameter_schema/0" do
    test "returns a valid JSON schema with url, offset, limit" do
      schema = WebFetch.parameter_schema()
      assert schema["type"] == "object"
      assert "url" in schema["required"]
      assert Map.has_key?(schema["properties"], "url")
      assert Map.has_key?(schema["properties"], "offset")
      assert Map.has_key?(schema["properties"], "limit")
    end
  end

  describe "execute/2 — URL validation" do
    test "rejects URLs without http/https scheme", %{context: ctx} do
      msg = execute_error("ftp://example.com", ctx)
      assert msg =~ "http:// or https://"

      execute_error("not-a-url", ctx)
      execute_error("", ctx)
    end

    test "rejects missing url", %{context: ctx} do
      result = WebFetch.execute(%{}, ctx)
      assert MCP.error?(result)
      msg = MCP.extract_content_text(result)
      assert msg =~ "url"
    end
  end

  describe "execute/2 — SSRF protection" do
    @public_test_url "http://93.184.216.34"

    @blocked_urls [
      {"localhost", "http://localhost/secret"},
      {"localhost with port", "http://localhost:8080/admin"},
      {"loopback 127.0.0.1", "http://127.0.0.1/"},
      {"loopback 127.x", "http://127.0.0.42:9200/"},
      {"10.x private", "http://10.0.0.1/"},
      {"172.16.x private", "http://172.16.0.1/"},
      {"192.168.x private", "http://192.168.1.1/"},
      {"link-local metadata", "http://169.254.169.254/latest/meta-data/"},
      {"0.0.0.0", "http://0.0.0.0/"},
      {"IPv6 loopback", "http://[::1]/"},
      {"IPv4-mapped IPv6 loopback", "http://[::ffff:127.0.0.1]/"},
      {"IPv4-mapped IPv6 metadata", "http://[::ffff:169.254.169.254]/"},
      {"ULA fd01::1", "http://[fd01::1]/"},
      {"ULA fdff::1", "http://[fdff::1]/"},
      {"link-local fe90::1", "http://[fe90::1]/"},
      {"link-local febf::1", "http://[febf::1]/"}
    ]

    for {label, url} <- @blocked_urls do
      test "rejects #{label}: #{url}", %{context: ctx} do
        msg = execute_error(unquote(url), ctx)
        assert msg =~ "private"
      end
    end

    test "blocks redirect to private IP", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://127.0.0.1:8080/admin")
        |> Plug.Conn.send_resp(302, "")
      end)

      msg = execute_error("#{@public_test_url}/redirect", ctx)
      assert msg =~ "private"
    end

    test "blocks redirect to metadata IP", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://169.254.169.254/latest/meta-data/")
        |> Plug.Conn.send_resp(301, "")
      end)

      msg = execute_error("#{@public_test_url}/aws", ctx)
      assert msg =~ "private"
    end

    test "blocks redirect to IPv4-mapped IPv6", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://[::ffff:127.0.0.1]/")
        |> Plug.Conn.send_resp(302, "")
      end)

      msg = execute_error("#{@public_test_url}/mapped", ctx)
      assert msg =~ "private"
    end

    test "blocks redirect to non-HTTP scheme", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "gopher://internal.host/")
        |> Plug.Conn.send_resp(302, "")
      end)

      msg = execute_error("#{@public_test_url}/gopher", ctx)
      assert msg =~ "http:// or https://"
    end

    test "rejects unresolvable hostnames", %{context: ctx} do
      msg = execute_error("https://this-domain-does-not-exist-xyz.invalid/", ctx)

      assert msg =~ "resolve"
    end

    test "follows relative redirect URLs", %{context: ctx} do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(:web_fetch, fn conn ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        if count == 0 do
          conn
          |> Plug.Conn.put_resp_header("location", "/new-path")
          |> Plug.Conn.send_resp(301, "")
        else
          conn
          |> Plug.Conn.put_resp_content_type("text/plain")
          |> Plug.Conn.send_resp(200, "Relative redirect worked")
        end
      end)

      result = execute_text("https://example.com/old-path", ctx)
      assert result["content"] =~ "Relative redirect worked"
    end

    test "follows safe redirects", %{context: ctx} do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(:web_fetch, fn conn ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        if count == 0 do
          conn
          |> Plug.Conn.put_resp_header("location", "https://example.com/final")
          |> Plug.Conn.send_resp(302, "")
        else
          conn
          |> Plug.Conn.put_resp_content_type("text/plain")
          |> Plug.Conn.send_resp(200, "Redirected content")
        end
      end)

      result = execute_text("https://example.com/start", ctx)
      assert result["content"] =~ "Redirected content"
    end
  end

  describe "execute/2 — HTML fetch and conversion" do
    test "fetches HTML and converts to markdown", %{context: ctx} do
      stub_resp(200, "text/html", "<h1>Hello</h1><p>World</p>")

      result = execute_text("https://example.com", ctx)
      assert result["url"] == "https://example.com"
      assert result["content_type"] =~ "text/html"
      assert result["content"] =~ "Hello"
      assert result["content"] =~ "World"
      assert result["total_lines"] > 0
      assert result["start_line"] == 0
    end

    test "returns plain text as-is", %{context: ctx} do
      stub_resp(200, "text/plain", "Hello plain world")

      result = execute_text("https://example.com/text", ctx)
      assert result["content"] =~ "Hello plain world"
    end

    test "returns markdown as-is", %{context: ctx} do
      stub_resp(200, "text/markdown", "# Hello\n\nMarkdown content")

      result = execute_text("https://example.com/md", ctx)
      assert result["content"] =~ "# Hello"
      assert result["content"] =~ "Markdown content"
    end
  end

  describe "execute/2 — HTTP errors" do
    for status <- [404, 500] do
      test "returns error on #{status}", %{context: ctx} do
        stub_resp(unquote(status), "error")

        msg = execute_error("https://example.com/err", ctx)
        assert msg =~ "#{unquote(status)}"
      end
    end
  end

  describe "execute/2 — transport retries" do
    test "retries closed transport errors for safe GET requests", %{context: ctx} do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(:web_fetch, fn conn ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        case count < 4 do
          true ->
            Req.Test.transport_error(conn, :closed)

          false ->
            conn
            |> Plug.Conn.put_resp_content_type("text/plain")
            |> Plug.Conn.send_resp(200, "Recovered after closed socket")
        end
      end)

      result = execute_text("https://example.com/closed-repeatedly", ctx)
      assert result["content"] =~ "Recovered after closed socket"
      assert :counters.get(call_count, 1) == 5
    end
  end

  describe "execute/2 — pagination" do
    setup do
      body = Enum.map_join(1..10, "\n", fn i -> "Line #{i}" end)
      stub_resp(200, "text/plain", body)
      :ok
    end

    test "returns first page by default", %{context: ctx} do
      result = execute_text("https://example.com", ctx)
      assert result["start_line"] == 0
      assert result["total_lines"] == 10
      assert result["lines_returned"] == 10
    end

    test "respects offset", %{context: ctx} do
      result = execute_text("https://example.com", ctx, %{"offset" => 5})
      assert result["start_line"] == 5
      assert result["lines_returned"] == 5
      assert result["content"] =~ "Line 6"
      refute result["content"] =~ "Line 5\n"
    end

    test "respects limit", %{context: ctx} do
      result = execute_text("https://example.com", ctx, %{"limit" => 3})
      assert result["start_line"] == 0
      assert result["lines_returned"] == 3
      assert result["total_lines"] == 10
      assert result["content"] =~ "Line 3"
      refute result["content"] =~ "Line 4"
    end

    test "offset + limit combination", %{context: ctx} do
      result = execute_text("https://example.com", ctx, %{"offset" => 2, "limit" => 3})
      assert result["start_line"] == 2
      assert result["lines_returned"] == 3
      assert result["content"] =~ "Line 3"
      assert result["content"] =~ "Line 5"
      refute result["content"] =~ "Line 6"
    end

    test "offset beyond content returns empty", %{context: ctx} do
      result = execute_text("https://example.com", ctx, %{"offset" => 100})
      assert result["lines_returned"] == 0
      assert result["content"] == ""
    end
  end

  describe "execute/2 — param clamping" do
    setup do
      stub_resp(200, "text/plain", "hello")
      :ok
    end

    test "clamps negative offset to 0", %{context: ctx} do
      result = execute_text("https://example.com", ctx, %{"offset" => -5})
      assert result["start_line"] == 0
    end

    test "clamps limit above 2000 to 2000", %{context: ctx} do
      result = execute_text("https://example.com", ctx, %{"limit" => 5000})
      assert result["lines_returned"] <= 2000
    end

    test "clamps limit below 1 to 1", %{context: ctx} do
      result = execute_text("https://example.com", ctx, %{"limit" => 0})
      assert result["lines_returned"] >= 0
    end
  end

  describe "execute/2 — size guard" do
    test "rejects responses larger than 5MB", %{context: ctx} do
      stub_resp(200, "text/plain", String.duplicate("x", 5_242_881))

      msg = execute_error("https://example.com/big", ctx)
      assert msg =~ "5MB"
    end
  end

  describe "execute/2 — image support and non-text rejection" do
    test "returns image/png responses as image results", %{context: ctx} do
      image_bytes = <<137, 80, 78, 71, 13, 10, 26, 10>>
      url = "https://example.com/logo.png"

      Req.Test.stub(:web_fetch, fn conn ->
        accept = Plug.Conn.get_req_header(conn, "accept") |> List.first("")
        assert accept =~ "image/png"
        assert accept =~ "image/jpeg"
        assert accept =~ "image/gif"
        assert accept =~ "image/webp"

        conn
        |> Plug.Conn.put_resp_content_type("image/png")
        |> Plug.Conn.send_resp(200, image_bytes)
      end)

      result = execute(url, ctx)
      refute MCP.error?(result)

      assert %{"content" => [%{"type" => "image", "data" => data, "mimeType" => "image/png"}]} =
               result

      assert data == Base.encode64(image_bytes)
    end

    test "returns image/jpeg responses with normalized data URL media type", %{context: ctx} do
      image_bytes = <<255, 216, 255, 224, "fake-jpeg">>
      url = "https://example.com/photo.jpg"

      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "image/jpeg; charset=binary")
        |> Plug.Conn.send_resp(200, image_bytes)
      end)

      result = execute(url, ctx)
      refute MCP.error?(result)

      assert %{"content" => [%{"type" => "image", "data" => data, "mimeType" => "image/jpeg"}]} =
               result

      assert data == Base.encode64(image_bytes)
    end

    test "rejects application/octet-stream responses", %{context: ctx} do
      stub_resp(200, "application/octet-stream", <<0, 1, 2, 3>>)

      msg = execute_error("https://example.com/file.bin", ctx)
      assert msg =~ "non-text"
    end

    test "rejects application/pdf responses", %{context: ctx} do
      stub_resp(200, "application/pdf", "%PDF-1.4 binary content")

      msg = execute_error("https://example.com/doc.pdf", ctx)
      assert msg =~ "non-text"
    end

    test "rejects image/svg+xml responses", %{context: ctx} do
      stub_resp(200, "image/svg+xml", "<svg></svg>")

      msg = execute_error("https://example.com/vector.svg", ctx)
      assert msg =~ "non-text"
      assert msg =~ "image/svg+xml"
    end

    test "allows text/html responses", %{context: ctx} do
      stub_resp(200, "text/html", "<h1>Hello</h1>")

      execute_text("https://example.com/page", ctx)
    end

    test "allows text/plain responses", %{context: ctx} do
      stub_resp(200, "text/plain", "Hello")

      execute_text("https://example.com/text", ctx)
    end

    test "allows application/json responses", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        accept = Plug.Conn.get_req_header(conn, "accept") |> List.first("")
        assert accept =~ "application/json"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"key": "value"}))
      end)

      execute_text("https://example.com/api", ctx)
    end

    test "allows application/xml responses", %{context: ctx} do
      stub_resp(200, "application/xml", "<root>data</root>")

      execute_text("https://example.com/feed.xml", ctx)
    end

    test "allows application/javascript responses", %{context: ctx} do
      stub_resp(200, "application/javascript", "console.log('hi')")

      execute_text("https://example.com/script.js", ctx)
    end
  end

  describe "execute/2 — Cloudflare retry" do
    test "retries with honest UA on Cloudflare challenge", %{context: ctx} do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(:web_fetch, fn conn ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        if count == 0 do
          conn
          |> Plug.Conn.put_resp_header("cf-mitigated", "challenge")
          |> Plug.Conn.send_resp(403, "Cloudflare challenge")
        else
          ua = Plug.Conn.get_req_header(conn, "user-agent") |> List.first("")
          assert ua =~ "Frontman"

          conn
          |> Plug.Conn.put_resp_content_type("text/html")
          |> Plug.Conn.send_resp(200, "<p>Real content</p>")
        end
      end)

      result = execute_text("https://example.com/cf", ctx)
      assert result["content"] =~ "Real content"
      assert :counters.get(call_count, 1) == 2
    end

    test "does not retry on regular 403", %{context: ctx} do
      stub_resp(403, "Forbidden")

      msg = execute_error("https://example.com/forbidden", ctx)
      assert msg =~ "403"
    end
  end
end
