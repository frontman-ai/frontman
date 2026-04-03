defmodule SwarmAi.ParallelExecutorTest do
  use ExUnit.Case, async: true

  alias SwarmAi.{Message.ContentPart, ParallelExecutor, Tool, ToolCall, ToolResult}

  defp make_tool(name, timeout_ms, on_timeout) do
    Tool.new(
      name: name,
      description: "test tool",
      parameter_schema: %{},
      timeout_ms: timeout_ms,
      on_timeout: on_timeout
    )
  end

  defp make_tc(id, name), do: %ToolCall{id: id, name: name, arguments: "{}"}

  defp start_sup do
    {:ok, sup} = Task.Supervisor.start_link()
    sup
  end

  defp instant_executor(tool_calls) do
    Enum.map(tool_calls, fn tc -> ToolResult.make(tc.id, "done:#{tc.name}", false) end)
  end

  defp content_text(%ToolResult{content: content}), do: ContentPart.extract_text(content)

  defp noop_deadline(_tc), do: :ok

  describe "run/5 — normal completion" do
    test "returns {:ok, results} for a single tool" do
      sup = start_sup()
      tool_map = %{"t1" => make_tool("t1", 5_000, :error)}

      result =
        ParallelExecutor.run([make_tc("id1", "t1")], tool_map, &instant_executor/1, sup, &noop_deadline/1)

      assert {:ok, [%ToolResult{id: "id1"} = r]} = result
      assert content_text(r) == "done:t1"
    end

    test "returns results in original order for concurrent tools" do
      sup = start_sup()

      tool_map = %{
        "slow" => make_tool("slow", 5_000, :error),
        "fast" => make_tool("fast", 5_000, :error)
      }

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          if tc.name == "slow", do: Process.sleep(50)
          ToolResult.make(tc.id, tc.name, false)
        end)
      end

      tcs = [make_tc("slow1", "slow"), make_tc("fast1", "fast")]
      {:ok, [r1, r2]} = ParallelExecutor.run(tcs, tool_map, executor, sup, &noop_deadline/1)

      assert r1.id == "slow1"
      assert r2.id == "fast1"
    end

    test "unknown tool name returns error ToolResult, no task spawned" do
      sup = start_sup()
      tool_map = %{}

      {:ok, [result]} =
        ParallelExecutor.run(
          [make_tc("id1", "unknown_tool")],
          tool_map,
          &instant_executor/1,
          sup,
          &noop_deadline/1
        )

      assert result.is_error == true
      assert content_text(result) =~ "Unknown tool"
    end
  end

  describe "run/5 — on_timeout: :error" do
    test "timed-out tool returns error ToolResult, agent continues" do
      sup = start_sup()
      tool_map = %{"slow" => make_tool("slow", 10, :error)}

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(500)
          ToolResult.make(tc.id, "too late", false)
        end)
      end

      {:ok, [result]} =
        ParallelExecutor.run([make_tc("id1", "slow")], tool_map, executor, sup, &noop_deadline/1)

      assert result.is_error == true
      assert content_text(result) =~ "timed out"
    end
  end

  describe "run/5 — on_timeout: :pause_agent" do
    test "returns {:halt, {:pause_agent, tool_name, timeout_ms}} on pause timeout" do
      sup = start_sup()
      tool_map = %{"interactive" => make_tool("interactive", 10, :pause_agent)}

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(500)
          ToolResult.make(tc.id, "never", false)
        end)
      end

      result =
        ParallelExecutor.run(
          [make_tc("id1", "interactive")],
          tool_map,
          executor,
          sup,
          &noop_deadline/1
        )

      assert {:halt, {:pause_agent, "id1", "interactive", 10}} = result
    end

    test "mixed batch: one pauses, others are cancelled, returns halt" do
      sup = start_sup()

      tool_map = %{
        "interactive" => make_tool("interactive", 20, :pause_agent),
        "normal" => make_tool("normal", 5_000, :error)
      }

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          if tc.name == "interactive", do: Process.sleep(500)
          ToolResult.make(tc.id, "result", false)
        end)
      end

      tcs = [make_tc("id1", "interactive"), make_tc("id2", "normal")]
      result = ParallelExecutor.run(tcs, tool_map, executor, sup, &noop_deadline/1)

      assert {:halt, {:pause_agent, "id1", "interactive", 20}} = result
    end

    test "two pause_agent tools with same timeout: exactly one halt returned" do
      sup = start_sup()

      tool_map = %{
        "a" => make_tool("a", 10, :pause_agent),
        "b" => make_tool("b", 10, :pause_agent)
      }

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(500)
          ToolResult.make(tc.id, "never", false)
        end)
      end

      result =
        ParallelExecutor.run(
          [make_tc("id1", "a"), make_tc("id2", "b")],
          tool_map,
          executor,
          sup,
          &noop_deadline/1
        )

      assert {:halt, {:pause_agent, _tool_call_id, _tool_name, 10}} = result
    end
  end

  describe "run/5 — task crash" do
    test "crashing tool produces error ToolResult, agent continues" do
      sup = start_sup()
      tool_map = %{"crasher" => make_tool("crasher", 5_000, :error)}

      executor = fn _tool_calls -> raise "boom" end

      {:ok, [result]} =
        ParallelExecutor.run([make_tc("id1", "crasher")], tool_map, executor, sup, &noop_deadline/1)

      assert result.is_error == true
      assert content_text(result) =~ "crashed"
    end
  end

  describe "run/5 — on_deadline callback" do
    test "calls on_deadline before terminating a timed-out :error tool" do
      sup = start_sup()
      test_pid = self()
      tool_map = %{"slow" => make_tool("slow", 10, :error)}

      on_deadline = fn tc -> send(test_pid, {:deadline_called, tc.id}) end

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(500)
          ToolResult.make(tc.id, "too late", false)
        end)
      end

      ParallelExecutor.run([make_tc("id1", "slow")], tool_map, executor, sup, on_deadline)
      assert_receive {:deadline_called, "id1"}, 1_000
    end

    test "calls on_deadline for remaining tools when pause_agent halts" do
      sup = start_sup()
      test_pid = self()

      tool_map = %{
        "interactive" => make_tool("interactive", 10, :pause_agent),
        "normal" => make_tool("normal", 5_000, :error)
      }

      on_deadline = fn tc -> send(test_pid, {:deadline_called, tc.id}) end

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(500)
          ToolResult.make(tc.id, "never", false)
        end)
      end

      ParallelExecutor.run(
        [make_tc("id1", "interactive"), make_tc("id2", "normal")],
        tool_map,
        executor,
        sup,
        on_deadline
      )

      deadline_ids =
        for _ <- 1..2 do
          assert_receive {:deadline_called, id}, 1_000
          id
        end

      assert Enum.sort(deadline_ids) == ["id1", "id2"]
    end
  end
end
