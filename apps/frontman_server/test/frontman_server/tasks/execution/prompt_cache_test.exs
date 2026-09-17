defmodule FrontmanServer.Tasks.Execution.PromptCacheTest do
  use FrontmanServer.ExecutionCase

  import FrontmanServer.DataCase, only: [setup_sandbox: 1]
  import FrontmanServer.InteractionCase.Helpers, only: [assert_receive_interaction: 2]
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Skills
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.{Providers, Repo, Tasks}
  alias FrontmanServer.Providers.OAuthToken
  alias FrontmanServer.Tasks.Interaction

  @cache %{"type" => "ephemeral"}

  setup [:setup_sandbox, :setup_user, :setup_task]

  setup do
    previous = Application.fetch_env!(:frontman_server, :llm_provider)
    Application.put_env(:frontman_server, :llm_provider, ReqLLM)
    on_exit(fn -> Application.put_env(:frontman_server, :llm_provider, previous) end)
    :ok
  end

  for {provider, model, auth, path} <- [
        {:anthropic, "claude-sonnet-4-6", :api_key, "/v1/messages"},
        {:anthropic, "claude-sonnet-4-6", :oauth, "/v1/messages"},
        {:openai_codex, "gpt-5.5", :oauth, "/codex/responses"},
        {:openrouter, "anthropic/claude-sonnet-4.6", :api_key, "/chat/completions"},
        {:openrouter, "~anthropic/claude-sonnet-latest", :api_key, "/chat/completions"},
        {:openrouter, "openai/gpt-5.5", :api_key, "/chat/completions"}
      ] do
    @tag provider: provider, model: model, auth: auth, path: path
    test "#{provider}:#{model} (#{auth}) preserves prefix caching as project context grows", %{
      scope: scope,
      task_id: task_id,
      provider: provider,
      model: model,
      auth: auth,
      path: path
    } do
      parent = self()
      skill = skill_fixture(scope)
      bypass = Bypass.open()
      previous = Application.fetch_env(:req_llm, provider)
      Application.put_env(:req_llm, provider, base_url: "http://localhost:#{bypass.port}")

      on_exit(fn ->
        case previous do
          {:ok, config} -> Application.put_env(:req_llm, provider, config)
          :error -> Application.delete_env(:req_llm, provider)
        end
      end)

      grant_provider_access(scope, provider, auth)

      execution =
        execution_request_fixture(
          model: "#{provider}:#{model}",
          project_traits: [:typescript, :react]
        )

      resolved_model = ReqLLM.model!(execution.model)

      Bypass.expect(bypass, "POST", path, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(parent, {:provider_request, Jason.decode!(body)})

        conn
        |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
        |> Plug.Conn.send_resp(200, response_events(provider))
      end)

      systems =
        for turn <- 1..4 do
          discover_project_context(scope, task_id, turn)
          text = "User turn #{turn}"

          assert {:ok, _, ^turn} =
                   submit_user_message_and_run(scope, task_id, execution, user_content(text))

          assert_receive_interaction(%Interaction.AgentCompleted{}, ^turn)
          refute_running_eventually(task_id)
          assert_receive {:provider_request, body}
          assert body["model"] == (resolved_model.provider_model_id || resolved_model.id)
          assert body["stream"] == true
          assert_cache_policy(provider, auth, body, text)
        end

      assert_project_growth(systems, skill)
      refute_receive {:provider_request, _}
    end
  end

  defp discover_project_context(scope, task_id, 2) do
    {:ok, _} =
      Tasks.add_discovered_project_structure(scope, task_id, "Project type: single project")

    {:ok, _} =
      Tasks.add_discovered_project_rules(scope, task_id, [{"AGENTS.md", "Use project rules."}])
  end

  defp discover_project_context(scope, task_id, 3) do
    {:ok, _} =
      Tasks.add_discovered_project_rules(scope, task_id, [
        {"src/AGENTS.md", "Use newly discovered rules."}
      ])
  end

  defp discover_project_context(_scope, _task_id, _turn), do: :ok

  defp assert_project_growth(systems, skill) do
    assert [initial, first, next, next] = systems
    refute initial =~ "## Project Structure"
    assert [prefix, first_context] = String.split(first, "## Project Structure", parts: 2)
    assert [^prefix, next_context] = String.split(next, "## Project Structure", parts: 2)
    assert prefix =~ "backend:#{skill.name}: #{skill.description}"
    assert first =~ "\n\n## Project Structure\n\n"

    for system <- systems do
      assert system =~ "Test executor system."
      assert system =~ "backend:#{skill.name}: #{skill.description}"
      refute system =~ skill.content
    end

    for context <- [first_context, next_context] do
      assert context =~ "Project type: single project"
      assert context =~ "Instructions from: AGENTS.md\nUse project rules."
    end

    refute first_context =~ "Use newly discovered rules."
    assert next_context =~ "Instructions from: src/AGENTS.md\nUse newly discovered rules."
  end

  defp assert_cache_policy(:openai_codex, _auth, body, text) do
    assert is_binary(body["instructions"])
    assert %{"role" => "user", "content" => [%{"text" => ^text}]} = List.last(body["input"])
    encoded = Jason.encode!(body)
    refute encoded =~ "cache_control"
    refute encoded =~ "anthropic_"
    body["instructions"]
  end

  defp assert_cache_policy(provider, auth, body, text) do
    assert %{"role" => "user", "content" => content} = List.last(body["messages"])

    {blocks, marker_count} =
      case provider do
        :anthropic ->
          assert [%{"text" => ^text, "cache_control" => @cache}] = content
          assert %{"cache_control" => @cache} = List.last(body["tools"])

          blocks =
            case auth do
              :api_key -> body["system"]
              :oauth -> Enum.drop(body["system"], 2)
            end

          for block <- blocks, do: assert(block["cache_control"] == @cache)
          {blocks, 2 + length(blocks)}

        :openrouter ->
          assert content == text
          assert [%{"role" => "system", "content" => blocks} | _] = body["messages"]
          {blocks, 1}
      end

    assert [prefix | context] = blocks
    assert length(context) <= 1
    assert prefix["cache_control"] == @cache
    refute prefix["text"] =~ "## Project Structure"

    for block <- context,
        do: assert(String.starts_with?(block["text"], "## Project Structure\n\n"))

    encoded = Jason.encode!(body)
    refute encoded =~ "anthropic_"
    assert length(Regex.scan(~r/"cache_control":/, encoded)) == marker_count
    Enum.map_join(blocks, "", & &1["text"])
  end

  defp grant_provider_access(scope, provider, :api_key) do
    :ok = Providers.upsert_api_key(scope, Atom.to_string(provider), "test-provider-key")
  end

  defp grant_provider_access(scope, provider, :oauth) do
    %OAuthToken{user_id: scope.user.id}
    |> OAuthToken.changeset(%{
      provider: Atom.to_string(provider),
      access_token: "test-provider-token",
      refresh_token: "test-refresh-token",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      metadata: %{"account_id" => "test-account"}
    })
    |> Repo.insert!()
  end

  defp response_events(:anthropic) do
    [
      %{
        type: "message_start",
        message: %{id: "msg_test", role: "assistant", content: [], usage: %{input_tokens: 10}}
      },
      %{type: "content_block_start", index: 0, content_block: %{type: "text", text: ""}},
      %{type: "content_block_delta", index: 0, delta: %{type: "text_delta", text: "Done"}},
      %{type: "content_block_stop", index: 0},
      %{type: "message_delta", delta: %{stop_reason: "end_turn"}, usage: %{output_tokens: 1}},
      %{type: "message_stop"}
    ]
    |> encode_events()
  end

  defp response_events(:openai_codex) do
    [
      %{type: "response.output_text.delta", delta: "Done", output_index: 0, content_index: 0},
      %{
        type: "response.completed",
        response: %{
          id: "resp_test",
          status: "completed",
          usage: %{input_tokens: 10, output_tokens: 1}
        }
      }
    ]
    |> encode_events()
  end

  defp response_events(:openrouter) do
    chunk = %{id: "resp_test", choices: [%{delta: %{content: "Done"}, finish_reason: "stop"}]}
    "data: #{Jason.encode!(chunk)}\n\ndata: [DONE]\n\n"
  end

  defp encode_events(events) do
    Enum.map_join(events, "", &"event: #{&1.type}\ndata: #{Jason.encode!(&1)}\n\n")
  end
end
