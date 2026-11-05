defmodule FrontmanServerWeb.MCPDiagnosticsTest do
  use FrontmanServer.DataCase, async: true

  import ExUnit.CaptureLog
  import Phoenix.ChannelTest
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 2]
  import FrontmanServer.InteractionCase.Helpers, only: [tool_call: 3]
  import FrontmanServerWeb.ChannelCase, only: [complete_mcp_handshake: 2]

  alias FrontmanServer.Protocols.{JsonRpc, MCP}
  alias FrontmanServerWeb.UserSocket

  @endpoint FrontmanServerWeb.Endpoint
  @image "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

  setup do
    scope = user_scope_fixture()
    task_id = task_fixture(scope, framework: "wordpress").id

    {:ok, _, socket} =
      UserSocket |> socket("user_id", %{scope: scope}) |> subscribe_and_join("task:#{task_id}")

    complete_mcp_handshake(socket,
      tools: [mcp_tool("testTool", %{"outputSchema" => %{"type" => "object"}})],
      load_project_context: false
    )

    {:ok, scope: scope, task_id: task_id, socket: socket}
  end

  test "dispatch and result diagnostics retain identifiers but exclude private payloads",
       context do
    %{socket: socket, task_id: task_id} = context
    {request_id, call_id} = dispatch(context)
    secret = "private-result-#{task_id}"

    result =
      MCP.tool_result_image(@image, "image/png")
      |> Map.put("structuredContent", %{"logged" => true})
      |> Map.put("_meta", %{"envApiKey" => secret})

    log =
      capture_log([metadata: :all], fn ->
        push(socket, "mcp:message", JsonRpc.success_response(request_id, result))
        :sys.get_state(socket.channel_pid)
      end)

    line = diagnostic(log, "MCP tool response received", call_id)
    assert line =~ "mcp_request_id=#{request_id}"
    assert line =~ "response_kind=result"
    refute log =~ secret
    refute log =~ @image
    refute log =~ "envApiKey"

    assert_receive {:tool_result, ^call_id,
                    [
                      %SwarmAi.Message.ContentPart{
                        type: :image,
                        data: image,
                        media_type: "image/png"
                      },
                      %SwarmAi.Message.ContentPart{type: :text, text: json}
                    ], false}

    assert image == Base.decode64!(@image)
    assert Jason.decode!(json) == %{"logged" => true}

    assert_push("acp:message", %{
      "params" => %{"sessionId" => ^task_id, "update" => %{"status" => "completed"}}
    })
  end

  test "error diagnostics exclude the error text while delivering it to the executor", context do
    %{socket: socket, task_id: task_id} = context
    {request_id, call_id} = dispatch(context)
    secret = "private-error-#{task_id}"

    log =
      capture_log([metadata: :all], fn ->
        push(socket, "mcp:message", JsonRpc.error_response(request_id, -32_000, secret))
        :sys.get_state(socket.channel_pid)
      end)

    line = diagnostic(log, "MCP tool response received", call_id)
    assert line =~ "mcp_request_id=#{request_id}"
    assert line =~ "response_kind=error"
    refute log =~ secret

    assert_receive {:tool_result, ^call_id,
                    [%SwarmAi.Message.ContentPart{type: :text, text: ^secret}], true}
  end

  defp dispatch(%{scope: scope, task_id: task_id, socket: socket}) do
    call_id = Ecto.UUID.generate()
    input = %{"private" => "private-input-#{task_id}"}
    call = tool_call(call_id, "testTool", input)
    turn = start_turn_fixture(scope, task_id)

    {:ok, _} =
      Registry.register(FrontmanServer.ProcessRegistry, {:tool_call, task_id, call_id}, %{
        caller_pid: self()
      })

    {request_id, log} =
      with_log([metadata: :all], fn ->
        assert {:ok, _} = persist_tool_call_fixture(scope, task_id, turn, call)

        assert_push("mcp:message", %{
          "id" => request_id,
          "method" => "tools/call",
          "params" => %{
            "name" => "testTool",
            "arguments" => ^input,
            "_meta" => %{
              "ai.frontman/execution-context" => %{"taskId" => ^task_id, "callId" => ^call_id}
            }
          }
        })

        :sys.get_state(socket.channel_pid)
        request_id
      end)

    assert is_integer(request_id)
    line = diagnostic(log, "MCP tool request pushed", call_id)
    assert line =~ "mcp_request_id=#{request_id}"
    assert line =~ "tool_name=testTool"
    refute log =~ input["private"]
    {request_id, call_id}
  end

  defp diagnostic(log, message, call_id) do
    assert [line] =
             log
             |> String.split("\n")
             |> Enum.filter(fn line ->
               case String.contains?(line, message) do
                 true -> String.contains?(line, "tool_call_id=#{call_id}")
                 false -> false
               end
             end)

    line
  end
end
