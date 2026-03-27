defmodule FrontmanServer.Tools.WebFetchTest do
  use FrontmanServer.DataCase, async: true

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
end
