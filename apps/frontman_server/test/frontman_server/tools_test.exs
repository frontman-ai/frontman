defmodule FrontmanServer.ToolsTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [tool_context: 1]

  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction.ToolResult
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.AgentFeedback
  alias FrontmanServer.Tools.GetToolResult
  alias FrontmanServer.Tools.TodoWrite
  alias FrontmanServer.Tools.WebFetch

  setup do
    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope, framework: "nextjs").id
    {:ok, task} = Tasks.get_task_with_history(scope, task_id)
    {:ok, task_id: task_id, task: task, scope: scope, turn_number: latest_turn_number(task_id)}
  end

  describe "resolve/2" do
    test "filters access and visibility while retaining MCP execution metadata" do
      definitions =
        Tools.MCP.from_maps([
          %{
            "name" => "read_mcp",
            "outputSchema" => %{"type" => "object"},
            "_meta" => %{
              "ai.frontman/tool-metadata" => %{
                "access" => "read",
                "executionMode" => "Interactive"
              }
            }
          },
          %{
            "name" => "write_mcp",
            "_meta" => %{"ai.frontman/tool-metadata" => %{"access" => "write"}}
          },
          %{"name" => "read_write_mcp"},
          %{
            "name" => "hidden_mcp",
            "_meta" => %{
              "ai.frontman/tool-metadata" => %{"access" => "read", "visibleToAgent" => false}
            }
          }
        ])

      read_tools = Tools.resolve(%{access: [:read]}, definitions)
      assert read_tools["read_mcp"] == hd(definitions)
      assert read_tools["web_fetch"] == WebFetch

      for name <- ~w(write_mcp read_write_mcp hidden_mcp todo_write) do
        refute Map.has_key?(read_tools, name)
      end

      all_tools = Tools.resolve(:all, definitions)

      for name <- ~w(read_mcp write_mcp read_write_mcp todo_write) do
        assert Map.has_key?(all_tools, name)
      end

      refute Map.has_key?(all_tools, "hidden_mcp")
      assert Tools.resolve(%{access: []}, definitions) == %{}
    end

    test "backend names win before filtering and never fall back to MCP" do
      definitions =
        Tools.MCP.from_maps([
          %{
            "name" => "todo_write",
            "_meta" => %{"ai.frontman/tool-metadata" => %{"access" => "read"}}
          }
        ])

      assert Tools.resolve(:all, definitions)["todo_write"] == TodoWrite
      refute Map.has_key?(Tools.resolve(%{access: [:read]}, definitions), "todo_write")

      refute Enum.any?(
               Tools.to_swarm_tools(Tools.resolve(%{access: [:read]}, definitions)),
               &(&1.name == "todo_write")
             )
    end
  end

  describe "to_swarm_tools/1" do
    test "tools have proper structure and deterministic name order" do
      definitions = Tools.MCP.from_maps([%{"name" => "zzz_mcp"}, %{"name" => "aaa_mcp"}])
      tools = Tools.resolve(:all, definitions) |> Tools.to_swarm_tools()
      names = Enum.map(tools, & &1.name)
      assert names == Enum.sort(names)
      assert "aaa_mcp" in names
      assert "zzz_mcp" in names

      Enum.each(tools, fn tool ->
        assert %SwarmAi.Tool{} = tool
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert tool.access in [:read, :write, :read_write]
        assert is_map(tool.parameter_schema)
      end)
    end

    test "tools expose expected access levels" do
      by_name =
        Tools.resolve(:all, []) |> Tools.to_swarm_tools() |> Map.new(&{&1.name, &1.access})

      assert by_name["agent_feedback"] == :read
      assert by_name["get_tool_result"] == :read
      assert by_name["web_fetch"] == :read
      assert by_name["todo_write"] == :write
    end
  end

  describe "find_tool/1" do
    test "finds registered tools" do
      for {tool_name, module} <- [
            {"agent_feedback", AgentFeedback},
            {"todo_write", TodoWrite},
            {"get_tool_result", GetToolResult},
            {"web_fetch", WebFetch}
          ] do
        assert Tools.find_tool(tool_name) == {:ok, module}
      end
    end

    test "returns :not_found for unavailable tools" do
      for tool_name <- ~w(nonexistent todo_add todo_update todo_remove todo_list) do
        assert Tools.find_tool(tool_name) == :not_found
      end
    end
  end

  describe "execution_target/1" do
    test "returns :backend for backend tools" do
      Enum.each(Tools.backend_tool_modules(), fn module ->
        assert Tools.execution_target(module.name()) == :backend
      end)
    end

    test "returns :mcp for non-backend tools" do
      assert Tools.execution_target("read_file") == :mcp
      assert Tools.execution_target("screenshot") == :mcp
      assert Tools.execution_target("unknown_tool") == :mcp
      assert Tools.execution_target("question") == :mcp
      assert Tools.execution_target("") == :mcp
    end
  end

  describe "todo_mutation?/1" do
    test "returns true for todo_write" do
      assert Tools.todo_mutation?("todo_write")
    end

    test "returns false for old todo tools and other tools" do
      refute Tools.todo_mutation?("todo_add")
      refute Tools.todo_mutation?("todo_update")
      refute Tools.todo_mutation?("todo_remove")
      refute Tools.todo_mutation?("todo_list")
      refute Tools.todo_mutation?("some_mcp_tool")
    end
  end

  describe "TodoWrite.execute/2" do
    test "writes a valid todo list", %{task: task} do
      context = tool_context(task)

      args = %{
        "todos" => [
          %{
            "content" => "Fix bug",
            "active_form" => "Fixing bug",
            "status" => "pending",
            "priority" => "high"
          },
          %{
            "content" => "Write tests",
            "active_form" => "Writing tests",
            "status" => "in_progress"
          }
        ]
      }

      result = TodoWrite.execute(args, context)
      refute MCP.error?(result)
      assert %{"todos" => todos} = result["structuredContent"]
      assert Jason.decode!(MCP.extract_content_text(result)) == result["structuredContent"]
      assert length(todos) == 2

      [first, second] = todos
      assert first["content"] == "Fix bug"
      assert first["priority"] == "high"
      assert first["status"] == "pending"
      assert is_binary(first["id"])

      assert second["content"] == "Write tests"
      assert second["priority"] == "medium"
      assert second["status"] == "in_progress"
    end

    test "accepts empty todos array", %{task: task} do
      context = tool_context(task)

      assert %{"structuredContent" => %{"todos" => []}} =
               TodoWrite.execute(%{"todos" => []}, context)
    end

    test "rejects invalid status", %{task: task} do
      context = tool_context(task)

      args = %{
        "todos" => [
          %{
            "content" => "Task",
            "active_form" => "Working",
            "status" => "invalid_status"
          }
        ]
      }

      result = TodoWrite.execute(args, context)
      assert MCP.error?(result)
      msg = MCP.extract_content_text(result)
      assert msg =~ "index 0"
    end

    test "rejects invalid priority", %{task: task} do
      context = tool_context(task)

      args = %{
        "todos" => [
          %{
            "content" => "Task",
            "active_form" => "Working",
            "status" => "pending",
            "priority" => "critical"
          }
        ]
      }

      result = TodoWrite.execute(args, context)
      assert MCP.error?(result)
      msg = MCP.extract_content_text(result)
      assert msg =~ "index 0"
    end

    test "rejects missing required fields", %{task: task} do
      context = tool_context(task)

      args = %{
        "todos" => [
          %{"content" => "Task"}
        ]
      }

      assert TodoWrite.execute(args, context) |> MCP.error?()
    end
  end

  describe "GetToolResult.execute/2" do
    test "returns the sanitized tool result by tool call ID", %{
      task_id: task_id,
      scope: scope,
      turn_number: turn_number
    } do
      untrusted_result = %{
        "content" => [
          %{"type" => "text", "text" => "file contents", "unknown" => "drop me"}
        ],
        "isError" => false,
        "_meta" => %{"envApiKey" => "sk-fake-stored-key"},
        "unknownTopLevel" => "drop me"
      }

      sanitized_result = %{
        "content" => [
          %{"type" => "text", "text" => "file contents", "unknown" => "drop me"}
        ],
        "isError" => false,
        "_meta" => %{}
      }

      {:ok, interaction, :no_executor} =
        Tasks.resolve_tool_request(
          scope,
          task_id,
          %{id: "tc-read", name: "read_file"},
          untrusted_result,
          turn_number: turn_number
        )

      {:ok, task} = Tasks.get_task_with_history(scope, task_id)
      context = tool_context(task)

      result = GetToolResult.execute(%{"tool_call_id" => "tc-read"}, context)

      assert result == sanitized_result
      assert interaction.result == sanitized_result
      assert interaction.tool_call_id == "tc-read"
    end

    test "returns an error when the interaction does not exist", %{task: task} do
      context = tool_context(task)

      result = GetToolResult.execute(%{"tool_call_id" => "missing"}, context)
      assert MCP.error?(result)
      assert MCP.extract_content_text(result) == "Tool result not found: missing"
    end

    test "returns an error when the stored result is malformed", %{task: task} do
      malformed_result =
        %ToolResult{
          id: Ecto.UUID.generate(),
          tool_call_id: "tc-malformed",
          tool_name: "read_file",
          result: %{"content" => "tool result text"},
          is_error: false,
          timestamp: DateTime.utc_now()
        }

      row = %InteractionSchema{id: Ecto.UUID.generate(), data: malformed_result}
      context = tool_context(%{task | interaction_rows: [row | task.interaction_rows]})

      result = GetToolResult.execute(%{"tool_call_id" => "tc-malformed"}, context)

      assert MCP.error?(result)

      assert MCP.extract_content_text(result) ==
               "Stored tool result for tc-malformed is not a valid MCP tool result"
    end
  end
end
