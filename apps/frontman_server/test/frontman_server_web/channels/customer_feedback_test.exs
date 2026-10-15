defmodule FrontmanServerWeb.CustomerFeedbackTest do
  use FrontmanServerWeb.ChannelCase, async: false
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 2]
  import FrontmanServer.ExecutionCase, only: [refute_running_eventually: 1]

  alias FrontmanServer.Protocols.{JsonRpc, MCP}
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Tools
  alias FrontmanServerWeb.UserSocket

  @name "request_customer_feedback"
  @moduletag :capture_log

  for output <- [%{"outcome" => "answered", "score" => 0}, %{"outcome" => "skipped"}] do
    test "persists #{output["outcome"]} through the normal MCP tool result path", %{scope: scope} do
      output = unquote(Macro.escape(output))
      task = task_fixture(scope)
      turn = start_turn_fixture(scope, task.id)
      call = %SwarmAi.ToolCall{id: "feedback", name: @name, arguments: "{}"}
      {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :interactive)

      {:ok, _, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task.id}", %{})

      complete_mcp_handshake(socket, tools: [mcp_tool(@name, %{})])
      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task.id}))
      assert_push("mcp:message", %{"id" => request_id, "method" => "tools/call"})

      {:ok, _} =
        Registry.register(FrontmanServer.ProcessRegistry, {:tool_call, task.id, call.id}, %{
          caller_pid: self()
        })

      result = MCP.tool_result_json(output) |> Map.put("structuredContent", output)
      push(socket, "mcp:message", JsonRpc.success_response(request_id, result))
      assert_receive {:tool_result, "feedback", [%{text: text}], false}, 1_000
      assert Jason.decode!(text) == output

      stored =
        InteractionSchema.for_task(task.id)
        |> InteractionSchema.of_type(:tool_result)
        |> Repo.one!()

      assert stored.data.result["structuredContent"] == output
    end
  end

  for eligible <- [true, false] do
    @tag eligible: eligible
    test "execution eligibility #{eligible} leaves the replay catalog intact",
         %{scope: scope} = context do
      FrontmanServer.BillingFixtures.allow_access_for_scope_fixture(scope)
      {:ok, _} = ReqLLM.model("openrouter:google/gemini-3.1-pro-preview")

      case context.eligible do
        false ->
          task = task_fixture(scope)
          turn = start_turn_fixture(scope, task.id)
          call = %SwarmAi.ToolCall{id: "previous", name: @name, arguments: "{}"}
          {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :interactive)

        true ->
          :ok
      end

      parent = self()

      Mox.expect(LLMProviderMock, :stream_text, fn _model, _messages, opts ->
        send(parent, {:execution_tools, Enum.map(opts[:tools], & &1.name)})
        ReqLLMResponses.response("Done")
      end)

      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket, tools: [mcp_tool(@name, %{}), mcp_tool("question", %{})])
      push(socket, "acp:message", build_prompt_request())
      assert_receive {:execution_tools, names}, 1_000
      assert @name in names == context.eligible
      assert "question" in names
      assert_push("acp:message", %{"params" => %{"update" => %{"state" => "idle"}}}, 1_000)

      channel_socket = :sys.get_state(socket.channel_pid)
      assert Enum.any?(channel_socket.assigns.mcp_tools, &(&1.name == @name))
      assert Map.has_key?(Tools.resolve(:all, channel_socket.assigns.mcp_tools), @name)
      refute_running_eventually(task_id)
    end
  end
end
