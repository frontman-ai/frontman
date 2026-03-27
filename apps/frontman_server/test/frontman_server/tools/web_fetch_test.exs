defmodule FrontmanServer.Tools.WebFetchTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Tools.WebFetch

  # Inject Req.Test as the HTTP adapter so no real network calls are made.
  setup do
    Application.put_env(:frontman_server, :web_fetch_req_options,
      plug: {Req.Test, :web_fetch}
    )

    on_exit(fn ->
      Application.delete_env(:frontman_server, :web_fetch_req_options)
    end)

    :ok
  end

  defp build_context do
    %FrontmanServer.Tools.Backend.Context{
      scope: nil,
      task: nil,
      tool_executor: fn _tool_call -> {:ok, "mock result"} end,
      llm_opts: [api_key: "test-key", model: "test-model"]
    }
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
    test "rejects URLs without http/https scheme" do
      context = build_context()

      assert {:error, msg} = WebFetch.execute(%{"url" => "ftp://example.com"}, context)
      assert msg =~ "http:// or https://"

      assert {:error, _} = WebFetch.execute(%{"url" => "not-a-url"}, context)
      assert {:error, _} = WebFetch.execute(%{"url" => ""}, context)
    end

    test "rejects missing url" do
      context = build_context()
      assert {:error, msg} = WebFetch.execute(%{}, context)
      assert msg =~ "url"
    end
  end

  describe "execute/2 — HTML fetch and conversion" do
    test "fetches HTML and converts to markdown" do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_resp(200, "<h1>Hello</h1><p>World</p>")
      end)

      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com"}, context)
      assert result["url"] == "https://example.com"
      assert result["content_type"] =~ "text/html"
      assert result["content"] =~ "Hello"
      assert result["content"] =~ "World"
      assert is_integer(result["total_lines"])
      assert result["total_lines"] > 0
      assert result["start_line"] == 0
      assert is_integer(result["lines_returned"])
    end

    test "returns plain text as-is" do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "Hello plain world")
      end)

      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com/text"}, context)
      assert result["content"] =~ "Hello plain world"
    end

    test "returns markdown as-is" do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/markdown")
        |> Plug.Conn.send_resp(200, "# Hello\n\nMarkdown content")
      end)

      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com/md"}, context)
      assert result["content"] =~ "# Hello"
      assert result["content"] =~ "Markdown content"
    end
  end

  describe "execute/2 — HTTP errors" do
    test "returns error on 404" do
      Req.Test.stub(:web_fetch, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      context = build_context()
      assert {:error, msg} = WebFetch.execute(%{"url" => "https://example.com/404"}, context)
      assert msg =~ "404"
    end

    test "returns error on 500" do
      Req.Test.stub(:web_fetch, fn conn ->
        Plug.Conn.send_resp(conn, 500, "Internal Server Error")
      end)

      context = build_context()
      assert {:error, msg} = WebFetch.execute(%{"url" => "https://example.com/500"}, context)
      assert msg =~ "500"
    end
  end

  describe "execute/2 — pagination" do
    setup do
      # 10 lines of content
      body = Enum.map_join(1..10, "\n", fn i -> "Line #{i}" end)

      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, body)
      end)

      :ok
    end

    test "returns first page by default" do
      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com"}, context)
      assert result["start_line"] == 0
      assert result["total_lines"] == 10
      assert result["lines_returned"] == 10
    end

    test "respects offset" do
      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com", "offset" => 5}, context)
      assert result["start_line"] == 5
      assert result["lines_returned"] == 5
      assert result["content"] =~ "Line 6"
      refute result["content"] =~ "Line 5\n"
    end

    test "respects limit" do
      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com", "limit" => 3}, context)
      assert result["start_line"] == 0
      assert result["lines_returned"] == 3
      assert result["total_lines"] == 10
      assert result["content"] =~ "Line 1"
      assert result["content"] =~ "Line 3"
      refute result["content"] =~ "Line 4"
    end

    test "offset + limit combination" do
      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com", "offset" => 2, "limit" => 3}, context)
      assert result["start_line"] == 2
      assert result["lines_returned"] == 3
      assert result["content"] =~ "Line 3"
      assert result["content"] =~ "Line 5"
      refute result["content"] =~ "Line 2\n"
      refute result["content"] =~ "Line 6"
    end

    test "offset beyond content returns empty" do
      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com", "offset" => 100}, context)
      assert result["start_line"] == 100
      assert result["lines_returned"] == 0
      assert result["content"] == ""
      assert result["total_lines"] == 10
    end
  end

  describe "execute/2 — param clamping" do
    setup do
      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "hello")
      end)

      :ok
    end

    test "clamps negative offset to 0" do
      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com", "offset" => -5}, context)
      assert result["start_line"] == 0
    end

    test "clamps limit above 2000 to 2000" do
      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com", "limit" => 5000}, context)
      assert result["lines_returned"] <= 2000
    end

    test "clamps limit below 1 to 1" do
      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com", "limit" => 0}, context)
      assert result["lines_returned"] >= 0
    end
  end

  describe "execute/2 — size guard" do
    test "rejects responses larger than 5MB" do
      big_body = String.duplicate("x", 5_242_881)

      Req.Test.stub(:web_fetch, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, big_body)
      end)

      context = build_context()
      assert {:error, msg} = WebFetch.execute(%{"url" => "https://example.com/big"}, context)
      assert msg =~ "5MB"
    end
  end

  describe "execute/2 — Cloudflare retry" do
    test "retries with honest UA on Cloudflare challenge (403 + cf-mitigated)" do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(:web_fetch, fn conn ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        if count == 0 do
          # First request — simulate Cloudflare challenge
          conn
          |> Plug.Conn.put_resp_header("cf-mitigated", "challenge")
          |> Plug.Conn.send_resp(403, "Cloudflare challenge")
        else
          # Retry — check for honest UA and return content
          ua = Plug.Conn.get_req_header(conn, "user-agent") |> List.first("")
          assert ua =~ "Frontman"

          conn
          |> Plug.Conn.put_resp_content_type("text/html")
          |> Plug.Conn.send_resp(200, "<p>Real content</p>")
        end
      end)

      context = build_context()
      assert {:ok, result} = WebFetch.execute(%{"url" => "https://example.com/cf"}, context)
      assert result["content"] =~ "Real content"
      assert :counters.get(call_count, 1) == 2
    end

    test "does not retry on regular 403 (no cf-mitigated header)" do
      Req.Test.stub(:web_fetch, fn conn ->
        Plug.Conn.send_resp(conn, 403, "Forbidden")
      end)

      context = build_context()
      assert {:error, msg} = WebFetch.execute(%{"url" => "https://example.com/forbidden"}, context)
      assert msg =~ "403"
    end
  end
end
