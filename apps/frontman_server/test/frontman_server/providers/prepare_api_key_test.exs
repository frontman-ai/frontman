defmodule FrontmanServer.Providers.PrepareApiKeyTest do
  @moduledoc "Tests credential resolution, provider request encoding, and streamed tool calls."
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.{Providers, Repo}
  alias FrontmanServer.Providers.OAuthToken
  alias ReqLLM.Providers.{Anthropic, OpenAICodex}

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    user = user_fixture()
    scope = %Scope{user: user}

    Req.Test.stub(:openai_oauth, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/backend-api/codex/models"

      Req.Test.json(conn, %{
        "models" =>
          Enum.map(~w(gpt-6.1-sol gpt-6-sol gpt-6-luna gpt-5.3-codex-spark), fn id ->
            %{"slug" => id, "visibility" => "list", "supported_in_api" => false}
          end)
      })
    end)

    {:ok, scope: scope}
  end

  describe "resolve_model_access/2 resolution priority" do
    test "resolves OAuth token as highest priority for anthropic", %{scope: scope} do
      {:ok, _} = upsert_anthropic_oauth_token(scope, :valid)
      :ok = upsert_anthropic_api_key(scope)

      {:ok, {model, llm_opts}} =
        Providers.resolve_model_access(scope, "anthropic:claude-sonnet-4-6")

      assert %LLMDB.Model{provider: :anthropic, id: "claude-sonnet-4-6"} = model
      assert llm_opts[:access_token] == "oauth_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:with_claude_subscription] == true
      assert llm_opts[:anthropic_prompt_cache] == true
      assert llm_opts[:anthropic_cache_messages] == -1
    end

    test "falls back to user key when no OAuth token", %{scope: scope} do
      :ok = upsert_anthropic_api_key(scope)

      {:ok, {model, llm_opts}} =
        Providers.resolve_model_access(scope, "anthropic:claude-sonnet-5")

      assert %LLMDB.Model{provider: :anthropic, id: "claude-sonnet-5"} = model
      assert llm_opts[:api_key] == "user_key_456"
      assert llm_opts[:anthropic_prompt_cache] == true
      assert llm_opts[:anthropic_cache_messages] == -1
    end

    test "returns :no_api_key when no key source is available", %{scope: scope} do
      assert {:error, :no_api_key} =
               Providers.resolve_model_access(scope, "anthropic:claude-sonnet-4-6")
    end

    test "refreshes expired Anthropic OAuth token before resolving LLM args", %{scope: scope} do
      {:ok, _} = upsert_anthropic_oauth_token(scope, :expired)
      expect_anthropic_refresh_success()

      {:ok, {_model, llm_opts}} =
        Providers.resolve_model_access(scope, "anthropic:claude-sonnet-4-6")

      assert llm_opts[:access_token] == "fresh_access"
      assert llm_opts[:auth_mode] == :oauth
    end

    test "invalid Anthropic refresh falls back to API key and deletes token", %{scope: scope} do
      {:ok, _} = upsert_anthropic_oauth_token(scope, :expired)
      :ok = upsert_anthropic_api_key(scope)

      expect_anthropic_refresh_permanent_failure()

      {:ok, {_model, llm_opts}} =
        Providers.resolve_model_access(scope, "anthropic:claude-sonnet-4-6")

      assert llm_opts[:api_key] == "user_key_456"
      refute oauth_token(scope, "anthropic")
    end

    test "transient Anthropic refresh failure keeps token and can recover", %{scope: scope} do
      {:ok, _} = upsert_anthropic_oauth_token(scope, :expired)
      :ok = upsert_anthropic_api_key(scope)
      expect_anthropic_refresh_transient_failure()

      {:ok, {_model, llm_opts}} =
        Providers.resolve_model_access(scope, "anthropic:claude-sonnet-4-6")

      assert llm_opts[:api_key] == "user_key_456"
      assert oauth_token(scope, "anthropic")

      expect_anthropic_refresh_success()

      {:ok, {_model, llm_opts}} =
        Providers.resolve_model_access(scope, "anthropic:claude-sonnet-4-6")

      assert llm_opts[:access_token] == "fresh_access"
    end

    test "returns :missing_model when no model is provided", %{scope: scope} do
      assert {:error, :missing_model} = Providers.resolve_model_access(scope, nil)
    end

    test "openrouter user key resolves correctly", %{scope: scope} do
      :ok = Providers.upsert_api_key(scope, "openrouter", "sk-or-user-test")

      {:ok, {model, llm_opts}} =
        Providers.resolve_model_access(scope, "openrouter:anthropic/claude-fable-5.1")

      assert %LLMDB.Model{provider: :openrouter, id: "anthropic/claude-fable-5.1"} = model
      assert llm_opts[:api_key] == "sk-or-user-test"
    end

    test "GPT-6 Codex requests retain OAuth routing and never store conversations", %{
      scope: scope
    } do
      {:ok, _} = upsert_openai_oauth_token(scope, :valid)

      for id <- ~w(gpt-6.1-sol gpt-6-sol gpt-6-luna) do
        {:ok, {model, opts}} = Providers.resolve_model_access(scope, "openai_codex:#{id}")
        {:ok, request} = OpenAICodex.prepare_request(:chat, model, "Hello", opts)
        body = request |> OpenAICodex.encode_body() |> Map.fetch!(:body) |> Jason.decode!()
        assert request.options[:base_url] == "https://chatgpt.com/backend-api"
        assert request.url.path == "/codex/responses"
        assert request.headers["authorization"] == ["Bearer openai_access"]
        assert request.headers["chatgpt-account-id"] == ["acc-789"]
        assert body["model"] == id
        assert body["store"] == false
      end
    end

    test "refreshes expired OpenAI OAuth token before resolving LLM args", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :expired)
      expect_openai_refresh_success()

      {:ok, {_model, llm_opts}} =
        Providers.resolve_model_access(scope, "openai_codex:gpt-5.3-codex-spark")

      assert llm_opts[:access_token] == "fresh_openai_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:chatgpt_account_id] == "acc-789"
    end

    test "permanent OpenAI refresh failure deletes expired OAuth token", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :expired)
      expect_openai_refresh_permanent_failure()

      assert {:error, :no_api_key} =
               Providers.resolve_model_access(scope, "openai_codex:gpt-5.3-codex-spark")

      refute oauth_token(scope, "openai_codex")
    end

    test "openai codex oauth without account id is invalid", %{scope: scope} do
      {:ok, _} =
        insert_oauth_token(
          scope,
          "openai_codex",
          "openai_access",
          "refresh",
          oauth_expiration(:valid)
        )

      assert {:error, :invalid_oauth_token} =
               Providers.resolve_model_access(scope, "openai_codex:gpt-6.1-sol")
    end

    test "reads runtime catalog and separates group, credential, and transport", %{scope: scope} do
      original_providers = Application.fetch_env!(:frontman_server, :providers)
      on_exit(fn -> Application.put_env(:frontman_server, :providers, original_providers) end)

      Application.put_env(:frontman_server, :providers,
        self_hosted: %{
          display_name: "Self-hosted",
          credential_source: "anthropic",
          models: [
            {"Qwen3 Coder", "qwen3-coder",
             %LLMDB.Model{
               provider: :openai,
               id: "qwen3-coder",
               base_url: "http://vllm:8000/v1"
             }}
          ]
        }
      )

      :ok = Providers.upsert_api_key(scope, "anthropic", "runtime-key")
      assert %{groups: [%{id: "self_hosted"}]} = Providers.available_models(scope)

      assert {:ok, {%LLMDB.Model{} = resolved_model, llm_opts}} =
               Providers.resolve_model_access(scope, "self_hosted:qwen3-coder")

      assert resolved_model.provider == :openai
      assert resolved_model.id == "qwen3-coder"
      assert resolved_model.base_url == "http://vllm:8000/v1"
      assert llm_opts[:api_key] == "runtime-key"
      refute llm_opts[:anthropic_prompt_cache]

      assert {:error, :unknown_model} =
               Providers.resolve_model_access(scope, "future_provider:missing")
    end
  end

  describe "OAuth availability refresh" do
    test "revoked Codex credentials require reconnection instead of outage retries", %{
      scope: scope
    } do
      {:ok, _} = upsert_openai_oauth_token(scope, :valid)

      Req.Test.stub(:openai_oauth, fn conn ->
        conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "token_invalidated"})
      end)

      assert %{groups: [], failed: []} = Providers.available_models(scope)

      assert {:error, :invalid_oauth_token} =
               Providers.resolve_model_access(scope, "openai_codex:gpt-6-sol")
    end

    test "Codex picker only advertises account models with supported transports", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :valid)

      Req.Test.expect(:openai_oauth, fn conn ->
        Req.Test.json(conn, %{
          "models" => [
            %{"slug" => "gpt-6-sol", "visibility" => "list", "supported_in_api" => false},
            %{"slug" => "gpt-6-astra", "visibility" => "hide"},
            %{"slug" => "gpt-6-luna", "visibility" => "none"},
            %{"slug" => "unconfigured-model", "visibility" => "list"}
          ]
        })
      end)

      assert %{groups: [%{id: "openai_codex", options: options}]} =
               Providers.available_models(scope)

      assert options == [%{name: "GPT-6 Sol", value: "openai_codex:gpt-6-sol"}]
    end

    test "rejects stale or forged Codex selections before inference", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :valid)

      for id <- ~w(gpt-6-astra gpt-6.1-sol) do
        Req.Test.expect(:openai_oauth, fn conn ->
          Req.Test.json(conn, %{
            "models" => [%{"slug" => "gpt-6-sol", "visibility" => "list"}]
          })
        end)

        assert {:error, :unknown_model} =
                 Providers.resolve_model_access(scope, "openai_codex:#{id}")
      end
    end

    test "checks each connected account separately", %{scope: scope} do
      other_scope = %Scope{user: user_fixture()}
      {:ok, _} = upsert_openai_oauth_token(scope, :valid)

      {:ok, _} =
        insert_oauth_token(
          other_scope,
          "openai_codex",
          "other_access",
          "other_refresh",
          oauth_expiration(:valid),
          %{"account_id" => "other-account"}
        )

      Req.Test.expect(:openai_oauth, 2, fn conn ->
        id =
          case Plug.Conn.get_req_header(conn, "chatgpt-account-id") do
            ["acc-789"] -> "gpt-6-sol"
            ["other-account"] -> "gpt-6-luna"
          end

        Req.Test.json(conn, %{"models" => [%{"slug" => id, "visibility" => "list"}]})
      end)

      assert %{groups: [%{options: [%{value: "openai_codex:gpt-6-sol"}]}]} =
               Providers.available_models(scope)

      assert %{groups: [%{options: [%{value: "openai_codex:gpt-6-luna"}]}]} =
               Providers.available_models(other_scope)
    end

    test "discovery failures never fall back to static Codex models", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :valid)
      :ok = upsert_anthropic_api_key(scope)

      Req.Test.stub(:openai_oauth, fn conn ->
        conn |> Plug.Conn.put_status(503) |> Req.Test.json(%{"error" => "private-input"})
      end)

      assert %{groups: [%{id: "anthropic"}]} = Providers.available_models(scope)

      assert {:error, :model_discovery_failed} =
               Providers.resolve_model_access(scope, "openai_codex:gpt-6-astra")
    end

    test "an empty account catalog hides the group and rejects selections", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :valid)
      Req.Test.stub(:openai_oauth, &Req.Test.json(&1, %{"models" => []}))

      assert %{groups: []} = Providers.available_models(scope)

      assert {:error, :unknown_model} =
               Providers.resolve_model_access(scope, "openai_codex:gpt-6-sol")
    end

    test "an API key alone cannot advertise or execute Codex models", %{scope: scope} do
      :ok = Providers.upsert_api_key(scope, "openai_codex", "not-a-chatgpt-connection")

      assert %{groups: []} = Providers.available_models(scope)

      assert {:error, :no_api_key} =
               Providers.resolve_model_access(scope, "openai_codex:gpt-6-sol")
    end

    test "picker discovery uses refreshed OpenAI credentials", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :expired)
      expect_openai_refresh_success()

      Req.Test.expect(:openai_oauth, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer fresh_openai_access"]
        Req.Test.json(conn, %{"models" => [%{"slug" => "gpt-6-sol", "visibility" => "list"}]})
      end)

      assert %{groups: [%{id: "openai_codex"}]} = Providers.available_models(scope)
    end

    test "model config refreshes expired Anthropic token", %{scope: scope} do
      {:ok, _} = upsert_anthropic_oauth_token(scope, :expired)
      expect_anthropic_refresh_success()

      config = Providers.available_models(scope)

      assert Enum.any?(config.groups, &(&1.id == "anthropic"))
    end

    test "connection status refreshes expired OpenAI token", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :expired)
      expect_openai_refresh_success()

      assert %{
               connected: true,
               expired: false,
               expires_at: expires_at
             } = Providers.resolve_oauth_connection_status(scope, "openai_codex")

      assert {:ok, refreshed_expires_at, _offset} = DateTime.from_iso8601(expires_at)
      assert DateTime.compare(refreshed_expires_at, DateTime.utc_now()) == :gt
    end
  end

  test "current Claude models encode required adaptive thinking through OAuth", %{scope: scope} do
    {:ok, _} = upsert_anthropic_oauth_token(scope, :valid)

    for id <- ~w(claude-opus-5-5 claude-sonnet-5-5 claude-fable-5-1 claude-haiku-5-5) do
      {:ok, {model, opts}} = Providers.resolve_model_access(scope, "anthropic:#{id}")

      {:ok, request} =
        Anthropic.prepare_request(
          :chat,
          model,
          "Hello",
          Keyword.put(opts, :reasoning_effort, :high)
        )

      body = Anthropic.encode_body(request).options[:json] |> Jason.encode!() |> Jason.decode!()
      assert request.headers["authorization"] == ["Bearer oauth_access"]
      assert body["model"] == id
      assert body["thinking"]["type"] == "adaptive"
      refute Map.has_key?(body, "temperature")
    end
  end

  describe "advertised provider execution" do
    for group <- [:nvidia, :fireworks_ai, :openrouter] do
      test "#{group} models send tools and decode streamed tool calls", %{scope: scope} do
        group = unquote(group)
        :ok = Providers.upsert_api_key(scope, to_string(group), "test-key")

        tools = [
          ReqLLM.Tool.new!(
            name: "lookup",
            description: "Look up a query",
            parameter_schema: [q: [type: :string, required: true]],
            callback: fn _ -> {:ok, "ok"} end
          )
        ]

        for entry <- Application.fetch_env!(:frontman_server, :providers)[group].models do
          id = elem(entry, 1)
          bypass = Bypass.open()

          Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
            {:ok, body, conn} = Plug.Conn.read_body(conn)
            body = Jason.decode!(body)
            assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-key"]
            assert body["model"] == id
            assert body["stream"] == true
            assert body["messages"] == [%{"role" => "user", "content" => "Hello"}]
            assert [%{"function" => %{"name" => "lookup"}}] = body["tools"]

            sse = ~S"""
            data: {"choices":[{"delta":{"content":"Hello"}}]}

            data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"lookup","arguments":"{\"q\":"}}]}}]}

            data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"elixir\"}"}}]}}]}

            data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}

            data: [DONE]

            """

            conn
            |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
            |> Plug.Conn.send_resp(200, sse)
          end)

          {:ok, {model, opts}} = Providers.resolve_model_access(scope, "#{group}:#{id}")
          opts = Keyword.merge(opts, base_url: "http://localhost:#{bypass.port}/v1", tools: tools)
          assert {:ok, stream} = ReqLLM.stream_text(model, "Hello", opts)
          assert {:ok, response} = ReqLLM.StreamResponse.to_response(stream)
          assert ReqLLM.Response.text(response) == "Hello"

          assert [%ReqLLM.ToolCall{id: "call_1", function: function}] =
                   ReqLLM.Response.tool_calls(response)

          assert %{name: "lookup", arguments: ~s({"q":"elixir"})} = function
        end
      end
    end
  end

  defp upsert_anthropic_api_key(scope) do
    Providers.upsert_api_key(scope, "anthropic", "user_key_456")
  end

  defp upsert_anthropic_oauth_token(scope, expiration) do
    insert_oauth_token(
      scope,
      "anthropic",
      anthropic_access_token(expiration),
      "refresh",
      oauth_expiration(expiration)
    )
  end

  defp anthropic_access_token(:valid), do: "oauth_access"
  defp anthropic_access_token(:expired), do: "expired_access"

  defp expect_anthropic_refresh_success do
    Req.Test.expect(:anthropic_oauth, fn conn ->
      Req.Test.json(conn, %{
        "access_token" => "fresh_access",
        "refresh_token" => "fresh_refresh",
        "expires_in" => 3600
      })
    end)
  end

  defp expect_anthropic_refresh_permanent_failure do
    Req.Test.expect(:anthropic_oauth, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{"error" => "invalid_grant"})
    end)
  end

  defp expect_anthropic_refresh_transient_failure do
    Req.Test.expect(:anthropic_oauth, fn conn ->
      conn
      |> Plug.Conn.put_status(500)
      |> Req.Test.json(%{"error" => "server_error"})
    end)
  end

  defp upsert_openai_oauth_token(scope, expiration) do
    insert_oauth_token(
      scope,
      "openai_codex",
      "openai_access",
      "refresh",
      oauth_expiration(expiration),
      %{"account_id" => "acc-789"}
    )
  end

  defp expect_openai_refresh_success do
    Req.Test.expect(:openai_oauth, fn conn ->
      Req.Test.json(conn, %{
        "access_token" => "fresh_openai_access",
        "refresh_token" => "fresh_openai_refresh",
        "expires_in" => 3600
      })
    end)
  end

  defp expect_openai_refresh_permanent_failure do
    Req.Test.expect(:openai_oauth, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{"error" => "invalid_grant"})
    end)
  end

  defp insert_oauth_token(
         scope,
         provider,
         access_token,
         refresh_token,
         expires_at,
         metadata \\ %{}
       ) do
    %OAuthToken{user_id: scope.user.id}
    |> OAuthToken.changeset(%{
      provider: provider,
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at,
      metadata: metadata
    })
    |> Repo.insert()
  end

  defp oauth_token(scope, provider) do
    OAuthToken |> OAuthToken.for_user_and_provider(scope.user.id, provider) |> Repo.one()
  end

  defp oauth_expiration(:valid), do: DateTime.add(DateTime.utc_now(), 3600, :second)
  defp oauth_expiration(:expired), do: DateTime.add(DateTime.utc_now(), -60, :second)
end
