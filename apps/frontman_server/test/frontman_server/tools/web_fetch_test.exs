defmodule FrontmanServer.Tools.WebFetchTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Tools.WebFetch

  setup do
    Application.put_env(:frontman_server, :web_fetch_req_options, plug: {Req.Test, :web_fetch})

    on_exit(fn ->
      Application.delete_env(:frontman_server, :web_fetch_req_options)
    end)

    context = %FrontmanServer.Tools.Backend.Context{
      scope: nil,
      task: nil,
      tool_executor: fn tool_calls ->
        Enum.map(tool_calls, fn tc -> SwarmAi.ToolResult.make(tc.id, "mock result", false) end)
      end,
      llm_opts: [api_key: "test-key", model: "test-model"]
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
      assert {:error, msg} = execute("ftp://example.com", ctx)
      assert msg =~ "http:// or https://"

      assert {:error, _} = execute("not-a-url", ctx)
      assert {:error, _} = execute("", ctx)
    end

    test "rejects missing url", %{context: ctx} do
      assert {:error, msg} = WebFetch.execute(%{}, ctx)
      assert msg =~ "url"
    end
  end

  describe "execute/2 — SSRF protection" do
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
        assert {:error, msg} = execute(unquote(url), ctx)
        assert msg =~ "private"
      end
    end

    test "blocks redirect to private IP", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://127.0.0.1:8080/admin")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, msg} = execute("https://evil.com/redirect", ctx)
      assert msg =~ "private"
    end

    test "blocks redirect to metadata IP", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://169.254.169.254/latest/meta-data/")
        |> Plug.Conn.send_resp(301, "")
      end)

      assert {:error, msg} = execute("https://evil.com/aws", ctx)
      assert msg =~ "private"
    end

    test "blocks redirect to IPv4-mapped IPv6", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://[::ffff:127.0.0.1]/")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, msg} = execute("https://evil.com/mapped", ctx)
      assert msg =~ "private"
    end

    test "blocks redirect to non-HTTP scheme", %{context: ctx} do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "gopher://internal.host/")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, msg} = execute("https://evil.com/gopher", ctx)
      assert msg =~ "http:// or https://"
    end

    test "rejects unresolvable hostnames", %{context: ctx} do
      assert {:error, msg} =
               execute("https://this-domain-does-not-exist-xyz.invalid/", ctx)

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

      assert {:ok, result} = execute("https://example.com/old-path", ctx)
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

      assert {:ok, result} = execute("https://example.com/start", ctx)
      assert result["content"] =~ "Redirected content"
    end
  end

  describe "execute/2 — HTML fetch and conversion" do
    test "fetches HTML and converts to markdown", %{context: ctx} do
      stub_resp(200, "text/html", "<h1>Hello</h1><p>World</p>")

      assert {:ok, result} = execute("https://example.com", ctx)
      assert result["url"] == "https://example.com"
      assert result["content_type"] =~ "text/html"
      assert result["content"] =~ "Hello"
      assert result["content"] =~ "World"
      assert result["total_lines"] > 0
      assert result["start_line"] == 0
    end

    test "returns plain text as-is", %{context: ctx} do
      stub_resp(200, "text/plain", "Hello plain world")

      assert {:ok, result} = execute("https://example.com/text", ctx)
      assert result["content"] =~ "Hello plain world"
    end

    test "returns markdown as-is", %{context: ctx} do
      stub_resp(200, "text/markdown", "# Hello\n\nMarkdown content")

      assert {:ok, result} = execute("https://example.com/md", ctx)
      assert result["content"] =~ "# Hello"
      assert result["content"] =~ "Markdown content"
    end
  end

  describe "execute/2 — HTTP errors" do
    for status <- [404, 500] do
      test "returns error on #{status}", %{context: ctx} do
        stub_resp(unquote(status), "error")

        assert {:error, msg} = execute("https://example.com/err", ctx)
        assert msg =~ "#{unquote(status)}"
      end
    end
  end

  describe "execute/2 — pagination" do
    setup do
      body = Enum.map_join(1..10, "\n", fn i -> "Line #{i}" end)
      stub_resp(200, "text/plain", body)
      :ok
    end

    test "returns first page by default", %{context: ctx} do
      assert {:ok, result} = execute("https://example.com", ctx)
      assert result["start_line"] == 0
      assert result["total_lines"] == 10
      assert result["lines_returned"] == 10
    end

    test "respects offset", %{context: ctx} do
      assert {:ok, result} = execute("https://example.com", ctx, %{"offset" => 5})
      assert result["start_line"] == 5
      assert result["lines_returned"] == 5
      assert result["content"] =~ "Line 6"
      refute result["content"] =~ "Line 5\n"
    end

    test "respects limit", %{context: ctx} do
      assert {:ok, result} = execute("https://example.com", ctx, %{"limit" => 3})
      assert result["start_line"] == 0
      assert result["lines_returned"] == 3
      assert result["total_lines"] == 10
      assert result["content"] =~ "Line 3"
      refute result["content"] =~ "Line 4"
    end

    test "offset + limit combination", %{context: ctx} do
      assert {:ok, result} = execute("https://example.com", ctx, %{"offset" => 2, "limit" => 3})
      assert result["start_line"] == 2
      assert result["lines_returned"] == 3
      assert result["content"] =~ "Line 3"
      assert result["content"] =~ "Line 5"
      refute result["content"] =~ "Line 6"
    end

    test "offset beyond content returns empty", %{context: ctx} do
      assert {:ok, result} = execute("https://example.com", ctx, %{"offset" => 100})
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
      assert {:ok, result} = execute("https://example.com", ctx, %{"offset" => -5})
      assert result["start_line"] == 0
    end

    test "clamps limit above 2000 to 2000", %{context: ctx} do
      assert {:ok, result} = execute("https://example.com", ctx, %{"limit" => 5000})
      assert result["lines_returned"] <= 2000
    end

    test "clamps limit below 1 to 1", %{context: ctx} do
      assert {:ok, result} = execute("https://example.com", ctx, %{"limit" => 0})
      assert result["lines_returned"] >= 0
    end
  end

  describe "execute/2 — size guard" do
    test "rejects responses larger than 5MB", %{context: ctx} do
      stub_resp(200, "text/plain", String.duplicate("x", 5_242_881))

      assert {:error, msg} = execute("https://example.com/big", ctx)
      assert msg =~ "5MB"
    end
  end

  describe "execute/2 — non-text content rejection" do
    test "rejects image/png responses", %{context: ctx} do
      # PNG header bytes
      stub_resp(200, "image/png", <<137, 80, 78, 71, 13, 10, 26, 10>>)

      assert {:error, msg} = execute("https://example.com/logo.png", ctx)
      assert msg =~ "non-text"
      assert msg =~ "image/png"
    end

    test "rejects image/jpeg responses", %{context: ctx} do
      stub_resp(200, "image/jpeg", <<255, 216, 255, 224>>)

      assert {:error, msg} = execute("https://example.com/photo.jpg", ctx)
      assert msg =~ "non-text"
    end

    test "rejects application/octet-stream responses", %{context: ctx} do
      stub_resp(200, "application/octet-stream", <<0, 1, 2, 3>>)

      assert {:error, msg} = execute("https://example.com/file.bin", ctx)
      assert msg =~ "non-text"
    end

    test "rejects application/pdf responses", %{context: ctx} do
      stub_resp(200, "application/pdf", "%PDF-1.4 binary content")

      assert {:error, msg} = execute("https://example.com/doc.pdf", ctx)
      assert msg =~ "non-text"
    end

    test "allows text/html responses", %{context: ctx} do
      stub_resp(200, "text/html", "<h1>Hello</h1>")

      assert {:ok, _} = execute("https://example.com/page", ctx)
    end

    test "allows text/plain responses", %{context: ctx} do
      stub_resp(200, "text/plain", "Hello")

      assert {:ok, _} = execute("https://example.com/text", ctx)
    end

    test "allows application/json responses", %{context: ctx} do
      stub_resp(200, "application/json", ~s({"key": "value"}))

      assert {:ok, _} = execute("https://example.com/api", ctx)
    end

    test "allows application/xml responses", %{context: ctx} do
      stub_resp(200, "application/xml", "<root>data</root>")

      assert {:ok, _} = execute("https://example.com/feed.xml", ctx)
    end

    test "allows application/javascript responses", %{context: ctx} do
      stub_resp(200, "application/javascript", "console.log('hi')")

      assert {:ok, _} = execute("https://example.com/script.js", ctx)
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

      assert {:ok, result} = execute("https://example.com/cf", ctx)
      assert result["content"] =~ "Real content"
      assert :counters.get(call_count, 1) == 2
    end

    test "does not retry on regular 403", %{context: ctx} do
      stub_resp(403, "Forbidden")

      assert {:error, msg} = execute("https://example.com/forbidden", ctx)
      assert msg =~ "403"
    end
  end
end
