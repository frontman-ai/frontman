defmodule FrontmanServer.Providers.PrepareApiKeyTest do
  @moduledoc """
  Integration tests for the full `Providers.resolve_model_access/3` resolution chain.

  Tests the priority order: OAuth > user key.
  This is the primary entry point for all LLM key resolution in the system.
  """
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.{Providers, Repo}
  alias FrontmanServer.Providers.{Nvidia, OAuthToken}
  alias ReqLLM.Context
  alias ReqLLM.Providers.Anthropic

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    user = user_fixture()
    scope = %Scope{user: user}
    {:ok, scope: scope}
  end

  describe "resolve_model_access/3 resolution priority" do
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

    test "resolved Anthropic opts mark the last message for prompt caching", %{scope: scope} do
      :ok = upsert_anthropic_api_key(scope)

      {:ok, {model, llm_opts}} =
        Providers.resolve_model_access(scope, "anthropic:claude-sonnet-4-6")

      context =
        Context.new([
          Context.system("system prompt"),
          Context.user("first user message"),
          Context.assistant("assistant reply"),
          Context.user("latest user message")
        ])

      {:ok, request} = Anthropic.prepare_request(:chat, model, context, llm_opts)
      encoded_request = Anthropic.encode_body(request)
      body = encoded_request.options[:json]

      last_message = List.last(body[:messages])
      [last_block] = last_message[:content]

      assert last_message[:role] == "user"
      assert last_block[:text] == "latest user message"
      assert last_block[:cache_control] == %{type: "ephemeral"}
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
        Providers.resolve_model_access(scope, "openrouter:anthropic/claude-fable-5")

      assert %LLMDB.Model{provider: :openrouter, id: "anthropic/claude-fable-5"} = model
      assert llm_opts[:api_key] == "sk-or-user-test"
    end

    test "openai codex oauth resolves direct ReqLLM args", %{scope: scope} do
      {:ok, _} = upsert_openai_oauth_token(scope, :valid)

      {:ok, {model, llm_opts}} =
        Providers.resolve_model_access(scope, "openai_codex:gpt-5.6-sol", max_tokens: 16_384)

      assert %LLMDB.Model{provider: :openai_codex, id: "gpt-5.6-sol"} = model
      assert llm_opts[:access_token] == "openai_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:chatgpt_account_id] == "acc-789"
      assert llm_opts[:max_tokens] == 16_384
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
               Providers.resolve_model_access(scope, "openai_codex:gpt-5.5")
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

  describe "packaged LLMDB metadata" do
    test "NVIDIA Kimi K2.6 no longer needs Frontman metadata" do
      model = ReqLLM.model!("nvidia:moonshotai/kimi-k2.6")

      assert model.capabilities.reasoning.enabled
      assert model.capabilities.streaming.tool_calls
      assert model.capabilities.tools.enabled
      assert model.limits == %{context: 262_144, output: 262_144}
      assert model.modalities == %{input: [:text, :image, :video], output: [:text]}
    end
  end

  describe "advertised provider execution" do
    test "NVIDIA models cross real provider dispatch and decode streaming responses", %{
      scope: scope
    } do
      :ok = Providers.upsert_api_key(scope, "nvidia", "nvapi-test")

      %{groups: groups} = Providers.available_models(scope)
      %{options: [nvidia_model | _]} = Enum.find(groups, &(&1.id == "nvidia"))
      bypass = Bypass.open()

      assert Nvidia.default_base_url() == "https://integrate.api.nvidia.com/v1"

      Bypass.expect(bypass, "POST", "/v1/chat/completions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer nvapi-test"]
        assert decoded_body["model"] == "moonshotai/kimi-k2.6"
        assert decoded_body["stream"] == true
        assert decoded_body["messages"] == [%{"role" => "user", "content" => "Hello"}]

        text_event = %{
          id: "chatcmpl-nvidia",
          choices: [%{delta: %{content: "Hello from NVIDIA"}}]
        }

        tool_event = %{
          id: "chatcmpl-nvidia",
          choices: [
            %{
              delta: %{
                tool_calls: [
                  %{
                    index: 0,
                    id: "call_1",
                    type: "function",
                    function: %{name: "lookup", arguments: ~s({"q":"elixir"})}
                  }
                ]
              }
            }
          ]
        }

        finished_event = %{
          id: "chatcmpl-nvidia",
          choices: [%{delta: %{}, finish_reason: "tool_calls"}]
        }

        sse_body =
          "data: #{Jason.encode!(text_event)}\n\n" <>
            "data: #{Jason.encode!(tool_event)}\n\n" <>
            "data: #{Jason.encode!(finished_event)}\n\n" <>
            "data: [DONE]\n\n"

        conn
        |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
        |> Plug.Conn.send_resp(200, sse_body)
      end)

      {:ok, {model, llm_opts}} =
        Providers.resolve_model_access(scope, nvidia_model.value,
          base_url: "http://localhost:#{bypass.port}/v1"
        )

      assert {:ok, stream_response} = ReqLLM.stream_text(model, "Hello", llm_opts)
      assert {:ok, response} = ReqLLM.StreamResponse.to_response(stream_response)
      assert ReqLLM.Response.text(response) == "Hello from NVIDIA"

      assert [%ReqLLM.ToolCall{id: "call_1", function: tool_function}] =
               ReqLLM.Response.tool_calls(response)

      assert tool_function == %{name: "lookup", arguments: ~s({"q":"elixir"})}
    end

    test "every advertised model resolves to executable transport" do
      for {group, %{models: models}} <- Application.fetch_env!(:frontman_server, :providers),
          model_entry <- models do
        model_id = elem(model_entry, 1)

        model_spec =
          case model_entry do
            {_name, ^model_id, model_spec} -> model_spec
            {_name, ^model_id} -> "#{group}:#{model_id}"
          end

        assert {:ok, model} = ReqLLM.model(model_spec),
               "advertised model #{group}:#{model_id} has no catalog metadata"

        assert {:ok, _provider} = ReqLLM.provider(model.provider),
               "advertised model #{group}:#{model_id} has no executable transport"
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
