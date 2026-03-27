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
end
