defmodule FrontmanServer.Tasks.Execution.PromptCacheTest do
  use FrontmanServer.ExecutionCase

  import FrontmanServer.DataCase, only: [setup_sandbox: 1]
  import FrontmanServer.InteractionCase.Helpers, only: [assert_receive_interaction: 2]
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Skills
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.OAuthToken
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks.Interaction

  setup [:setup_sandbox, :setup_user, :setup_task]

  setup do
    previous = Application.fetch_env!(:frontman_server, :llm_provider)
    Application.put_env(:frontman_server, :llm_provider, ReqLLM)
    on_exit(fn -> Application.put_env(:frontman_server, :llm_provider, previous) end)
    :ok
  end

  for {provider, model, path} <- [
        {:anthropic, "claude-sonnet-4-6", "/v1/messages"},
        {:openai_codex, "gpt-5.5", "/codex/responses"}
      ] do
    @tag provider: provider, model: model, path: path
    test "#{provider} preserves the skill prefix and provider cache policy on the wire", %{
      scope: scope,
      task_id: task_id,
      provider: provider,
      model: model,
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

      grant_provider_access(scope, provider)
      execution = execution_request_fixture(model: "#{provider}:#{model}")

      Bypass.expect(bypass, "POST", path, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(parent, {:provider_request, Jason.decode!(body)})

        conn
        |> Plug.Conn.put_resp_header("content-type", "text/event-stream")
        |> Plug.Conn.send_resp(200, response_events(provider))
      end)

      systems =
        for turn <- 1..2 do
          text = "User turn #{turn}"

          assert {:ok, _, ^turn} =
                   submit_user_message_and_run(scope, task_id, execution, user_content(text))

          assert_receive_interaction(%Interaction.AgentCompleted{}, ^turn)
          refute_running_eventually(task_id)
          assert_receive {:provider_request, body}
          assert body["model"] == model
          assert body["stream"] == true
          assert_cache_policy(provider, body, text)
        end

      assert [system, system] = systems
      assert system =~ "Test executor system."
      assert system =~ "backend:#{skill.name}"
      assert system =~ skill.description
      refute system =~ skill.content
      refute_receive {:provider_request, _}
    end
  end

  defp assert_cache_policy(:anthropic, body, text) do
    assert %{"cache_control" => %{"type" => "ephemeral"}} = List.last(body["system"])
    assert %{"cache_control" => %{"type" => "ephemeral"}} = List.last(body["tools"])
    assert %{"role" => "user", "content" => [last_block]} = List.last(body["messages"])
    assert last_block["text"] == text
    assert last_block["cache_control"] == %{"type" => "ephemeral"}
    Enum.map_join(body["system"], "", & &1["text"])
  end

  defp assert_cache_policy(:openai_codex, body, text) do
    assert is_binary(body["instructions"])
    assert %{"role" => "user", "content" => [%{"text" => ^text}]} = List.last(body["input"])
    encoded = Jason.encode!(body)
    refute encoded =~ "cache_control"
    refute encoded =~ "anthropic_"
    body["instructions"]
  end

  defp grant_provider_access(scope, :anthropic) do
    :ok = Providers.upsert_api_key(scope, "anthropic", "test-provider-key")
  end

  defp grant_provider_access(scope, :openai_codex) do
    %OAuthToken{user_id: scope.user.id}
    |> OAuthToken.changeset(%{
      provider: "openai_codex",
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

  defp encode_events(events) do
    Enum.map_join(events, "", &"event: #{&1.type}\ndata: #{Jason.encode!(&1)}\n\n")
  end
end
