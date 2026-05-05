defmodule FrontmanServer.Observability.OtelHandlerTest do
  @moduledoc """
  Integration tests for OTEL span hierarchy and OpenInference attributes.

  These tests run actual agents through production code paths and verify
  the resulting telemetry spans have correct structure and attributes
  for Arize Phoenix consumption.

  Expected trace structure (OpenInference span kinds):
  ```
  task (CHAIN, root)
  └── agent (AGENT)
      └── step N (CHAIN)
          ├── chat (LLM)
          └── tool (TOOL)
  ```
  """
  use FrontmanServer.ExecutionCase

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.InteractionCase.Helpers
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction

  require Record
  Record.defrecord(:span, Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl"))

  # Span field accessors (positions from otel_span.hrl)
  defp field(span, :trace_id), do: elem(span, 1)
  defp field(span, :span_id), do: elem(span, 2)
  defp field(span, :parent_span_id), do: elem(span, 4)
  defp field(span, :name), do: elem(span, 6)
  defp field(span, :attributes), do: elem(span, 10)

  defp attr(span, key) do
    case field(span, :attributes) do
      {:attributes, _, _, _, list} -> find_attr(list, key)
      list when is_list(list) -> find_attr(list, key)
      _ -> nil
    end
  end

  defp find_attr(list, key) do
    case Enum.find(list, fn {k, _} -> k == key or to_string(k) == to_string(key) end) do
      {_, v} -> v
      nil -> nil
    end
  end

  setup do
    # Set up database sandbox
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    scope = user_scope_fixture()

    ensure_ets_tables()
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    task_id = task_with_pubsub_fixture(scope, framework: "nextjs")

    on_exit(&cleanup_ets_tables/0)
    {:ok, task_id: task_id, scope: scope}
  end

  describe "full trace hierarchy" do
    test "complete parent-child chain with all expected attributes", %{
      task_id: task_id,
      scope: scope
    } do
      # Run a real agent with a tool call through production code
      tool_call = swarm_tool_call("todo_write")

      expect_llm_responses([{:tool_calls, [tool_call], ""}, "Here are your todos"])

      {:ok, _} =
        Tasks.submit_user_message(
          scope,
          task_id,
          [%{"type" => "text", "text" => "Show my todos"}],
          []
        )

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # Collect spans from this trace
      spans = collect_spans_for_task(task_id)

      # Verify we got expected span types (using OpenInference naming)
      task = by_name(spans, "task")
      agent = by_name(spans, "agent")
      step_spans = all_by_name(spans, ~r/^step/)
      llm_spans = all_by_name(spans, ~r/^chat/)
      tool = by_name(spans, ~r/^tool /)

      assert task != nil, "Missing task span"
      assert agent != nil, "Missing agent span"
      assert step_spans != [], "Missing step spans"
      assert llm_spans != [], "Missing LLM span"
      assert tool != nil, "Missing tool span"

      # === Parent-Child Chain ===
      assert_parent_child(task, nil, "task should be root")
      assert_parent_child(agent, task, "agent → task")

      for step <- step_spans do
        assert_parent_child(step, agent, "step → agent")
      end

      # Each LLM span should have a step parent (from step_spans)
      step_ids = Enum.map(step_spans, &field(&1, :span_id))

      for llm <- llm_spans do
        llm_parent_id = field(llm, :parent_span_id)
        llm_name = field(llm, :name)

        assert llm_parent_id in step_ids,
               "llm '#{llm_name}' → step (parent #{inspect(llm_parent_id)} not in step_ids #{inspect(step_ids)})"
      end

      # Tool should have a step parent
      tool_parent_id = field(tool, :parent_span_id)
      step_ids = Enum.map(step_spans, &field(&1, :span_id))
      assert tool_parent_id in step_ids, "tool → step"

      # === Shared Trace ID ===
      trace_id = field(task, :trace_id)
      all_spans = [task, agent, tool] ++ step_spans ++ llm_spans

      for span <- all_spans do
        assert field(span, :trace_id) == trace_id, "#{field(span, :name)} has wrong trace_id"
      end

      # === Task Attributes (OpenInference) ===
      assert attr(task, :"session.id") == task_id
      assert attr(task, :"openinference.span.kind") == "CHAIN"

      # === Agent Attributes (OpenInference) ===
      assert attr(agent, :"openinference.span.kind") == "AGENT"
      assert attr(agent, :"session.id") == task_id

      # === Step Attributes (OpenInference) ===
      step = hd(step_spans)
      assert attr(step, :"openinference.span.kind") == "CHAIN"

      # === LLM Attributes (OpenInference) ===
      llm = hd(llm_spans)
      assert attr(llm, :"openinference.span.kind") == "LLM"
      assert is_binary(attr(llm, :"llm.model_name"))

      # === Tool Attributes (OpenInference) ===
      assert attr(tool, :"openinference.span.kind") == "TOOL"
      assert attr(tool, :"tool.name") == "todo_write"
      assert attr(tool, :"tool.parameters") != nil, "Tool span should have parameters"
      assert attr(tool, :"tool.output") != nil, "Tool span should have output"

      # === Verify LLM span has tool calls ===
      first_llm = hd(llm_spans)

      assert attr(
               first_llm,
               :"llm.output_messages.0.message.tool_calls.0.tool_call.function.name"
             ) ==
               "todo_write",
             "LLM span should capture tool call name"
    end

    test "simple text response creates expected spans", %{task_id: task_id, scope: scope} do
      expect_llm_responses(["Hello!"])

      {:ok, _} =
        Tasks.submit_user_message(
          scope,
          task_id,
          [%{"type" => "text", "text" => "Hi"}],
          []
        )

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      spans = collect_spans_for_task(task_id)

      task = by_name(spans, "task")
      agent = by_name(spans, "agent")
      step = by_name(spans, ~r/^step/)
      llm = by_name(spans, ~r/^chat/)

      assert task != nil
      assert agent != nil
      assert step != nil
      assert llm != nil

      # Verify chain
      assert_parent_child(agent, task, "agent → task")
      assert_parent_child(step, agent, "step → agent")
      assert_parent_child(llm, step, "llm → step")

      # === Verify LLM input messages ===
      # System prompt should be first message
      assert attr(llm, :"llm.input_messages.0.message.role") == "system",
             "LLM span should have system message as input"

      assert is_binary(attr(llm, :"llm.input_messages.0.message.content")),
             "System message should have content"

      # User message should be second
      assert attr(llm, :"llm.input_messages.1.message.role") == "user",
             "LLM span should have user message as input"

      assert attr(llm, :"llm.input_messages.1.message.content") =~ "Hi",
             "User message content should match"

      # === Verify LLM output messages ===
      assert attr(llm, :"llm.output_messages.0.message.role") == "assistant",
             "LLM span should have assistant output"

      assert attr(llm, :"llm.output_messages.0.message.content") =~ "Hello!",
             "Output content should match LLM response"
    end
  end

  # ===========================================================================
  # Assertion & Collection Helpers
  # ===========================================================================

  defp assert_parent_child(child, nil, msg) do
    parent_id = field(child, :parent_span_id)
    assert parent_id == :undefined or parent_id == nil, msg
  end

  defp assert_parent_child(child, parent, msg) do
    assert field(child, :parent_span_id) == field(parent, :span_id), msg
  end

  defp by_name(spans, name) when is_binary(name) do
    Enum.find(spans, fn s ->
      n = field(s, :name)
      n == name or to_string(n) == name
    end)
  end

  defp by_name(spans, regex) do
    Enum.find(spans, fn s -> Regex.match?(regex, to_string(field(s, :name))) end)
  end

  defp all_by_name(spans, regex) do
    Enum.filter(spans, fn s -> Regex.match?(regex, to_string(field(s, :name))) end)
  end

  defp collect_spans_for_task(task_id) do
    # Collect all spans from the mailbox
    all_spans = collect_spans([])

    # Find the task span for this task_id (using session.id attribute)
    task_span =
      Enum.find(all_spans, fn s ->
        to_string(field(s, :name)) == "task" and attr(s, :"session.id") == task_id
      end)

    if task_span do
      trace_id = field(task_span, :trace_id)
      Enum.filter(all_spans, &(field(&1, :trace_id) == trace_id))
    else
      []
    end
  end

  defp collect_spans(acc) do
    receive do
      {:span, s} -> collect_spans([s | acc])
    after
      200 -> Enum.reverse(acc)
    end
  end

  defp ensure_ets_tables do
    tables = ~w(task mcp loop swarm_step llm tool spawn)a

    for t <- tables do
      name = :"frontman_spans_#{t}"

      if :ets.info(name) == :undefined do
        :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
      end
    end
  end

  defp cleanup_ets_tables do
    tables = ~w(task mcp loop swarm_step llm tool spawn)a

    for t <- tables do
      name = :"frontman_spans_#{t}"
      if :ets.info(name) != :undefined, do: :ets.delete_all_objects(name)
    end
  end
end
