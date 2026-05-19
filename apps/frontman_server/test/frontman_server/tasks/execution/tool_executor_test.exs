defmodule FrontmanServer.Tasks.Execution.ToolExecutorTest do
  @moduledoc """
  Focused tests for ToolExecutor callback shaping and result enrichment.
  """

  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend

  # --- Fake backend tools ---

  # A backend tool that declares on_timeout: :pause_agent.
  defmodule PauseOnTimeoutTool do
    @behaviour Backend

    def name, do: "pause_on_timeout_tool"
    def description, do: "Declares on_timeout: :pause_agent"
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 30_000
    def on_timeout, do: :pause_agent

    def execute(_args, _context), do: {:ok, "done"}
  end

  setup do
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "tool_executor_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

    llm_opts = [api_key: "test-key", model: "openrouter:anthropic/claude-sonnet-4-20250514"]

    {:ok, scope: scope, task_id: task_id, llm_opts: llm_opts}
  end

  defp tool_results(task, tool_call_id) do
    Enum.filter(task.interactions, fn
      %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
      _ -> false
    end)
  end

  describe "handle_timeout/5 — cancelled tools" do
    @tag :capture_log
    test "persists error ToolResult for :error policy", %{
      scope: scope,
      task_id: task_id
    } do
      tc = %SwarmAi.ToolCall{id: "tc-to-2", name: "some_tool", arguments: "{}"}
      ToolExecutor.handle_timeout(scope, task_id, :error, tc, :cancelled)

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, tc.id)
    end

    @tag :capture_log
    test "persists ToolResult for :pause_agent policy", %{
      scope: scope,
      task_id: task_id
    } do
      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: PauseOnTimeoutTool.name(),
        arguments: "{}"
      }

      ToolExecutor.handle_timeout(scope, task_id, :pause_agent, tc, :cancelled)

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, tc.id)
    end
  end

  describe "run_backend_tool/5 — non-JSON-serializable result" do
    defmodule BinaryResultTool do
      @behaviour Backend

      def name, do: "binary_result_tool"
      def description, do: "Returns raw binary that breaks JSON encoding"
      def parameter_schema, do: %{"type" => "object", "properties" => %{}}
      def timeout_ms, do: 30_000
      def on_timeout, do: :error

      # Simulates a tool returning raw PNG bytes
      def execute(_args, _context), do: {:ok, %{"content" => <<137, 80, 78, 71, 13, 10, 26, 10>>}}
    end

    @tag :capture_log
    test "converts non-JSON-serializable result to error instead of crashing", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      exec_opts = %{
        backend_tool_modules: [BinaryResultTool],
        backend_module_map: %{BinaryResultTool.name() => BinaryResultTool},
        mcp_tools: [],
        mcp_tool_defs: [],
        llm_opts: llm_opts
      }

      tool_call = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: BinaryResultTool.name(),
        arguments: "{}"
      }

      result =
        ToolExecutor.run_backend_tool(scope, BinaryResultTool, task_id, exec_opts, tool_call)

      assert %SwarmAi.ToolResult{is_error: true} = result
      assert [%SwarmAi.Message.ContentPart{type: :text, text: text}] = result.content
      assert text =~ "JSON"
    end
  end

  describe "make_executor/3 — execution descriptors" do
    test "executor returns ToolExecution.Sync for backend tools", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      executor =
        ToolExecutor.make_executor(scope, task_id,
          backend_tool_modules: [PauseOnTimeoutTool],
          mcp_tools: [],
          mcp_tool_defs: [],
          llm_opts: llm_opts
        )

      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: PauseOnTimeoutTool.name(),
        arguments: "{}"
      }

      [execution] = executor.([tc])

      assert %SwarmAi.ToolExecution.Sync{
               on_timeout_policy: :pause_agent,
               on_timeout: {ToolExecutor, :handle_timeout, [^scope, ^task_id, :pause_agent]}
             } = execution
    end

    test "executor returns ToolExecution.Await for MCP tools", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      pause_mcp_def = %FrontmanServer.Tools.MCP{
        name: "some_mcp_tool",
        description: "test",
        input_schema: %{},
        on_timeout: :pause_agent,
        timeout_ms: 60_000
      }

      executor =
        ToolExecutor.make_executor(scope, task_id,
          backend_tool_modules: [],
          mcp_tools: [],
          mcp_tool_defs: [pause_mcp_def],
          llm_opts: llm_opts
        )

      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: "some_mcp_tool",
        arguments: "{}"
      }

      [execution] = executor.([tc])

      assert %SwarmAi.ToolExecution.Await{
               on_timeout_policy: :pause_agent,
               message_key: tc_id,
               on_timeout: {ToolExecutor, :handle_timeout, [^scope, ^task_id, :pause_agent]}
             } = execution

      assert tc_id == tc.id

      assert execution.process_result == {ToolExecutor, :make_mcp_tool_result, [tc.name]}
    end
  end

  describe "make_mcp_tool_result/4" do
    test "enriches web_fetch image result with image content part" do
      image_bytes = <<255, 216, 255, 224, "fake-jpeg">>
      image_url = "https://example.com/cat.jpg"

      json_content =
        Jason.encode!(%{
          "type" => "image",
          "url" => image_url,
          "content_type" => "image/jpeg",
          "image" => "data:image/jpeg;base64,#{Base.encode64(image_bytes)}"
        })

      tool_call = %SwarmAi.ToolCall{id: "tc_web_fetch", name: "web_fetch", arguments: "{}"}

      result = ToolExecutor.make_mcp_tool_result("web_fetch", tool_call, json_content, false)

      assert %SwarmAi.ToolResult{id: "tc_web_fetch", is_error: false} = result

      assert [
               %SwarmAi.Message.ContentPart{
                 type: :image,
                 data: ^image_bytes,
                 media_type: "image/jpeg"
               }
             ] = result.content
    end

    test "returns plain text ToolResult for non-image tool" do
      json_content = Jason.encode!(%{"output" => "hello world"})

      tool_call = %SwarmAi.ToolCall{
        id: "tc_read",
        name: "mcp_read_file",
        arguments: "{}"
      }

      result = ToolExecutor.make_mcp_tool_result("mcp_read_file", tool_call, json_content, false)

      assert %SwarmAi.ToolResult{id: "tc_read", is_error: false} = result
      assert [%SwarmAi.Message.ContentPart{type: :text, text: ^json_content}] = result.content
    end
  end
end
