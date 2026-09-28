defmodule SwarmAi.ParallelExecutorTest do
  use ExUnit.Case, async: true

  alias SwarmAi.{Message.ContentPart, ParallelExecutor, ToolCall, ToolExecution, ToolResult}

  def run_instant(content, tool_call), do: ToolResult.make(tool_call.id, content, false)

  def run_slow(delay_ms, content, tool_call) do
    Process.sleep(delay_ms)
    run_instant(content, tool_call)
  end

  def run_crash(_tool_call), do: raise("boom")

  def record_error(test_pid, reason, tool_call) do
    send(test_pid, {:error_called, tool_call.id, reason})
    SwarmAi.Testing.default_tool_error(reason, tool_call)
  end

  def start_await(test_pid, tool_call) do
    send(test_pid, {:await_started, tool_call.id, self()})
    :ok
  end

  def start_await_soon(content, tool_call) do
    Process.send_after(self(), {:tool_result, tool_call.id, content, false}, 10)
    :ok
  end

  def start_await_immediate(tool_call) do
    send(self(), {:tool_result, tool_call.id, "immediate", false})
    :ok
  end

  def start_await_gate(test_pid, tool_call) do
    start_await(test_pid, tool_call)

    receive do
      :start -> :ok
    after
      1_000 -> raise "Await start gate was not released"
    end
  end

  def store_then_wait(table, test_pid, tool_call) do
    :ets.insert(table, {:worker, self()})
    result = ToolResult.make(tool_call.id, "stored success", false)
    true = :ets.insert_new(table, {tool_call.id, result})
    send(test_pid, {:sync_started, self()})

    receive do
      :return -> result
    after
      5_000 -> raise "Sync gate was not released or killed"
    end
  end

  def store_then_crash(table, tool_call) do
    result = ToolResult.make(tool_call.id, "stored success", false)
    true = :ets.insert_new(table, {tool_call.id, result})
    exit(:crashed_after_persistence)
  end

  def canonical_error(table, test_pid, reason, tool_call) do
    case :ets.lookup(table, :worker) do
      [{:worker, pid}] ->
        false = Process.alive?(pid)
        send(pid, :return)

      [] ->
        :ok
    end

    :ets.insert_new(table, {tool_call.id, SwarmAi.Testing.default_tool_error(reason, tool_call)})
    [{_, result}] = :ets.lookup(table, tool_call.id)
    send(test_pid, {:error_called, tool_call.id, reason})
    result
  end

  defp make_tc(id), do: %ToolCall{id: id, name: id, arguments: "{}"}

  defp sync_exec(id) do
    %ToolExecution.Sync{
      tool_call: make_tc(id),
      timeout_ms: 5_000,
      run: {__MODULE__, :run_instant, ["done:#{id}"]},
      on_error: {SwarmAi.Testing, :default_tool_error, []}
    }
  end

  defp await_exec(id, timeout_ms \\ :infinity) do
    %ToolExecution.Await{
      tool_call: make_tc(id),
      timeout_ms: timeout_ms,
      start: {__MODULE__, :start_await, [self()]},
      on_error: {__MODULE__, :record_error, [self()]}
    }
  end

  defp start_sup, do: start_supervised!(Task.Supervisor)
  defp content_text(%ToolResult{content: content}), do: ContentPart.extract_text(content)

  test "returns results for empty batches" do
    sup = start_sup()
    assert ParallelExecutor.run([], sup) == {:ok, []}
    assert ParallelExecutor.run_serial([], sup) == {:ok, []}
  end

  test "Sync normal completion and original order despite out-of-order completion" do
    slow = %{sync_exec("slow") | run: {__MODULE__, :run_slow, [50, "slow"]}}
    assert {:ok, [first, second]} = ParallelExecutor.run([slow, sync_exec("fast")], start_sup())
    assert first.id == "slow"
    assert content_text(first) == "slow"
    assert second.id == "fast"
    assert content_text(second) == "done:fast"
  end

  test "infinite Await accepts a later answer without a deadline" do
    exec = %{await_exec("human") | start: {__MODULE__, :start_await_soon, ["answer"]}}

    assert {:ok, [%ToolResult{id: "human", is_error: false}]} =
             ParallelExecutor.run([exec], start_sup())
  end

  test "Await error result propagates its content and error flag" do
    sup = start_sup()
    exec = await_exec("human")
    task = Task.async(fn -> ParallelExecutor.run([exec], sup) end)
    assert_receive {:await_started, "human", pid}
    send(pid, {:tool_result, "human", "client error", true})
    assert {:ok, [result]} = Task.await(task)
    assert result.is_error
    assert content_text(result) == "client error"
  end

  test "infinite Await survives a finite Sync sibling deadline and keeps batch order" do
    sup = start_sup()
    human = await_exec("human")

    slow = %{
      sync_exec("slow")
      | timeout_ms: 20,
        run: {__MODULE__, :run_slow, [5_000, "too late"]},
        on_error: {__MODULE__, :record_error, [self()]}
    }

    task = Task.async(fn -> ParallelExecutor.run([human, slow, sync_exec("fast")], sup) end)
    assert_receive {:await_started, "human", pid}
    assert_receive {:error_called, "slow", :timeout}, 1_000
    assert Task.yield(task, 50) == nil
    refute_receive {:error_called, "human", _}, 0
    assert Task.Supervisor.children(sup) == []

    send(pid, {:tool_result, "human", "answer", false})
    assert {:ok, [answer, error, fast]} = Task.await(task)
    assert {answer.id, content_text(answer), answer.is_error} == {"human", "answer", false}
    assert {error.id, error.is_error} == {"slow", true}
    assert fast.id == "fast"
  end

  test "serial interactive call blocks later dispatch until answered" do
    sup = start_sup()
    executions = [await_exec("first"), await_exec("second")]
    task = Task.async(fn -> ParallelExecutor.run_serial(executions, sup) end)
    assert_receive {:await_started, "first", pid}
    refute_receive {:await_started, "second", _}, 50
    send(pid, {:tool_result, "first", "first answer", false})
    assert_receive {:await_started, "second", ^pid}
    send(pid, {:tool_result, "second", "second answer", false})
    assert {:ok, results} = Task.await(task)
    assert Enum.map(results, & &1.id) == ["first", "second"]
  end

  test "parallel Await results keep original order" do
    sup = start_sup()
    executions = [await_exec("first"), await_exec("second")]
    task = Task.async(fn -> ParallelExecutor.run(executions, sup) end)
    assert_receive {:await_started, "first", pid}
    assert_receive {:await_started, "second", ^pid}
    send(pid, {:tool_result, "second", "second answer", false})
    assert Task.yield(task, 20) == nil
    send(pid, {:tool_result, "first", "first answer", false})
    assert {:ok, results} = Task.await(task)
    assert Enum.map(results, & &1.id) == ["first", "second"]
  end

  test "crashing Sync tool persists an error without cancelling siblings" do
    table = :ets.new(:canonical_results, [:public, :set])

    crash = %{
      sync_exec("crash")
      | run: {__MODULE__, :run_crash, []},
        on_error: {__MODULE__, :canonical_error, [table, self()]}
    }

    assert {:ok, [error, success]} = ParallelExecutor.run([crash, sync_exec("ok")], start_sup())
    assert error.is_error
    assert content_text(error) =~ "crashed"
    assert [{"crash", ^error}] = :ets.lookup(table, "crash")
    assert_receive {:error_called, "crash", {:crashed, {%RuntimeError{message: "boom"}, _}}}
    refute success.is_error
  end

  test "finite Await deadline returns callback result" do
    assert {:ok, [result]} = ParallelExecutor.run([await_exec("finite", 10)], start_sup())
    assert result == SwarmAi.Testing.default_tool_error(:timeout, make_tc("finite"))
    assert_receive {:error_called, "finite", :timeout}
    refute_receive {:error_called, "finite", _}, 20
  end

  test "Sync is dead before timeout persistence and its stored success wins" do
    sup = start_sup()
    table = :ets.new(:canonical_results, [:public, :set])

    exec = %{
      sync_exec("sync")
      | timeout_ms: 100,
        run: {__MODULE__, :store_then_wait, [table, self()]},
        on_error: {__MODULE__, :canonical_error, [table, self()]}
    }

    task = Task.async(fn -> ParallelExecutor.run([exec], sup) end)
    assert_receive {:sync_started, pid}
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000
    assert_receive {:error_called, "sync", :timeout}
    assert {:ok, [result]} = Task.await(task)
    assert [{"sync", ^result}] = :ets.lookup(table, "sync")
    refute result.is_error
    assert content_text(result) == "stored success"
    assert Task.Supervisor.children(sup) == []
  end

  test "Sync success persisted before a crash remains the canonical result" do
    table = :ets.new(:canonical_results, [:public, :set])

    exec = %{
      sync_exec("sync")
      | run: {__MODULE__, :store_then_crash, [table]},
        on_error: {__MODULE__, :canonical_error, [table, self()]}
    }

    assert {:ok, [result]} = ParallelExecutor.run([exec], start_sup())
    assert [{"sync", ^result}] = :ets.lookup(table, "sync")
    refute result.is_error
    assert_receive {:error_called, "sync", {:crashed, :crashed_after_persistence}}
    refute_receive {:error_called, "sync", _}, 20
  end

  test "Await answer stored before deadline wins even when delivery is delayed" do
    sup = start_sup()
    table = :ets.new(:canonical_results, [:public, :set])
    winner = ToolResult.make("human", "stored answer", false)
    :ets.insert(table, {"human", winner})

    exec = %{
      await_exec("human", 10)
      | on_error: {__MODULE__, :canonical_error, [table, self()]}
    }

    assert {:ok, [^winner]} = ParallelExecutor.run([exec], sup)
  end

  test "timeout stored first wins and late answers cannot override it" do
    sup = start_sup()
    table = :ets.new(:canonical_results, [:public, :set])

    finite = %{
      await_exec("finite", 10)
      | on_error: {__MODULE__, :canonical_error, [table, self()]}
    }

    executions = [finite, await_exec("human")]
    task = Task.async(fn -> ParallelExecutor.run(executions, sup) end)
    assert_receive {:await_started, "human", pid}
    assert_receive {:error_called, "finite", :timeout}, 1_000
    late = ToolResult.make("finite", "late answer", false)
    refute :ets.insert_new(table, {"finite", late})
    send(pid, {:tool_result, "finite", late.content, late.is_error})
    send(pid, {:tool_result, "human", "answer", false})
    assert {:ok, [result, _]} = Task.await(task)
    assert [{"finite", ^result}] = :ets.lookup(table, "finite")
    assert result.is_error
    refute_receive {:error_called, "finite", _}, 20
  end

  test "a queued stale deadline cannot overwrite a completed result" do
    sup = start_sup()
    first = %{await_exec("first", 10) | start: {__MODULE__, :start_await_immediate, []}}
    second = %{await_exec("second") | start: {__MODULE__, :start_await_gate, [self()]}}
    task = Task.async(fn -> ParallelExecutor.run([first, second], sup) end)
    assert_receive {:await_started, "second", pid}
    Process.sleep(30)
    {:messages, messages} = Process.info(pid, :messages)
    assert Enum.any?(messages, &match?({:deadline, _}, &1))
    send(pid, :start)
    send(pid, {:tool_result, "second", "answer", false})
    assert {:ok, [first_result, _]} = Task.await(task)
    assert content_text(first_result) == "immediate"
    refute first_result.is_error
    refute_receive {:error_called, "first", _}, 20
  end
end
