defmodule FrontmanServerWeb.TaskChannelUnknownToolRecoveryTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.InteractionCase.Helpers, only: [assert_receive_interaction: 2]

  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses

  test "planner recovers when model calls a tool filtered from current MCP capabilities", %{
    scope: scope
  } do
    parent = self()
    tool_call_id = "toolu_filtered_read_file"
    calls = :counters.new(1, [])
    {socket, task_id} = join_task_channel(scope, framework: "vite")

    complete_mcp_handshake(socket,
      tools: [
        %{
          "name" => "read_file",
          "description" => "Read a file",
          "access" => "read-write",
          "inputSchema" => %{
            "type" => "object",
            "properties" => %{"path" => %{"type" => "string"}}
          },
          "visibleToAgent" => true
        }
      ]
    )

    {:ok, _api_key} = Providers.upsert_api_key(scope, "anthropic", "sk-ant-test")

    Mox.stub(LLMProviderMock, :stream_text, fn model, messages, opts ->
      :counters.add(calls, 1, 1)
      invocation = :counters.get(calls, 1)
      tool_names = Enum.map(opts[:tools], & &1.name)

      case invocation do
        1 ->
          send(parent, {:initial_provider_request, model, tool_names})

          ReqLLMResponses.response(
            {:tool_calls,
             [
               %SwarmAi.ToolCall{
                 id: tool_call_id,
                 name: "read_file",
                 arguments: ~s({"path":"src/index.css"})
               }
             ], "Inspecting the file"}
          )

        2 ->
          send(parent, {:continued_provider_request, model, messages})
          ReqLLMResponses.response("The tool is unavailable, so I continued without it.")
      end
    end)

    ref =
      push(
        socket,
        "acp:message",
        build_prompt_request(
          text: "Inspect the implementation and prepare a plan",
          _meta: %{
            "model" => %{"provider" => "anthropic", "value" => "claude-sonnet-4-6"},
            "agent" => "test-planner"
          }
        )
      )

    assert_reply(ref, :ok, %{"acp:message" => %{"result" => %{}}})

    assert_receive {
                     :initial_provider_request,
                     "anthropic:claude-sonnet-4-6",
                     initial_tool_names
                   },
                   5_000

    refute "read_file" in initial_tool_names

    assert_receive {
                     :continued_provider_request,
                     "anthropic:claude-sonnet-4-6",
                     continued_messages
                   },
                   5_000

    assert Enum.any?(continued_messages, fn
             %{role: :assistant, tool_calls: tool_calls} ->
               Enum.any?(List.wrap(tool_calls), &(&1.id == tool_call_id))

             _message ->
               false
           end)

    assert Enum.any?(continued_messages, fn
             %{role: :tool, tool_call_id: ^tool_call_id} -> true
             _message -> false
           end)

    assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

    assert {:ok, task} = Tasks.get_task(scope, task_id)

    refute Enum.any?(Tasks.interactions(task), fn
             %Interaction.ToolCall{tool_call_id: ^tool_call_id} -> true
             _interaction -> false
           end)

    assert Enum.any?(Tasks.interactions(task), fn
             %Interaction.ToolResult{tool_call_id: ^tool_call_id, is_error: true} -> true
             _interaction -> false
           end)

    assert Enum.any?(Tasks.interactions(task), &match?(%Interaction.AgentCompleted{}, &1))
    refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.AgentError{}, &1))
  end
end
