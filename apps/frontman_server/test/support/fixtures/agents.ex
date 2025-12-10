defmodule FrontmanServer.Test.Fixtures.Agents do
  @moduledoc """
  Reusable fixtures for agent-related tests.

  These fixtures are orthogonal to test cases - any test module can use them
  via the setup tag mechanism or by calling the functions directly.

  ## Usage with AgentCase

      use FrontmanServer.AgentCase, async: true

      @tag fixtures: [:parent_agent, :fake_sub_agent]
      test "something", %{parent_agent: parent, fake_sub_agent: sub} do
        inject_sub_agent(parent.pid, sub)
        # ...
      end

  ## Direct usage

      import FrontmanServer.Test.Fixtures.Agents

      setup do
        ctx = build_fixtures([:event_collector, :parent_agent], %{})
        on_exit(fn -> cleanup_agents(ctx) end)
        ctx
      end
  """

  alias FrontmanServer.Agents.{Agent, AgentServer, SubAgent}
  alias ReqLLM.ToolCall

  @doc """
  Build multiple fixtures from a list of atoms.

  Fixtures are built in order, and later fixtures can depend on earlier ones.
  """
  @spec build_fixtures([atom()], map()) :: map()
  def build_fixtures(fixtures, tags \\ %{}) do
    base = %{
      test_pid: self(),
      unique_id: System.unique_integer([:positive])
    }

    Enum.reduce(fixtures, base, fn fixture, ctx ->
      build_fixture(fixture, ctx, tags)
    end)
  end

  @doc "Build a single fixture"
  @spec build_fixture(atom(), map(), map()) :: map()
  def build_fixture(:event_collector, ctx, _tags) do
    test_pid = ctx.test_pid
    on_event = fn event -> send(test_pid, {:event, event}) end
    Map.merge(ctx, %{on_event: on_event})
  end

  def build_fixture(:parent_agent, ctx, tags) do
    ctx = ensure_fixture(ctx, :event_collector, tags)

    agent_id = tags[:parent_id] || "parent_#{ctx.unique_id}"
    task_id = tags[:task_id] || "task_#{ctx.unique_id}"
    llm_opts = build_llm_opts(ctx, tags)

    {:ok, pid} =
      GenServer.start_link(AgentServer, {:root, %{
        agent_id: agent_id,
        task_id: task_id,
        tools: tags[:tools] || [],
        on_event: ctx.on_event,
        llm_opts: llm_opts
      }})

    Map.merge(ctx, %{
      parent_agent: %{pid: pid, id: agent_id, task_id: task_id}
    })
  end

  def build_fixture(:registered_parent_agent, ctx, tags) do
    ctx = ensure_fixture(ctx, :event_collector, tags)

    agent_id = tags[:parent_id] || "parent_#{ctx.unique_id}"
    task_id = tags[:task_id] || "task_#{ctx.unique_id}"
    llm_opts = build_llm_opts(ctx, tags)

    {:ok, pid} =
      GenServer.start_link(
        AgentServer,
        {:root, %{
          agent_id: agent_id,
          task_id: task_id,
          tools: tags[:tools] || [],
          on_event: ctx.on_event,
          llm_opts: llm_opts
        }},
        name: via_registry(agent_id, task_id, nil, :root)
      )

    Map.merge(ctx, %{
      parent_agent: %{pid: pid, id: agent_id, task_id: task_id, registered: true}
    })
  end

  def build_fixture(:sub_agent, ctx, tags) do
    ctx = ensure_fixture(ctx, :event_collector, tags)

    agent_id = tags[:sub_agent_id] || "sub_#{ctx.unique_id}"
    task_id = get_in(ctx, [:parent_agent, :task_id]) || tags[:task_id] || "task_#{ctx.unique_id}"
    parent_id = get_in(ctx, [:parent_agent, :id]) || tags[:parent_agent_id] || "fake_parent"
    parent_pid = get_in(ctx, [:parent_agent, :pid]) || self()

    {:ok, pid} =
      GenServer.start_link(AgentServer, {:sub_agent, %{
        agent_id: agent_id,
        task_id: task_id,
        tools: tags[:tools] || [],
        on_event: ctx.on_event,
        parent_agent_id: parent_id,
        parent_pid: parent_pid,
        role: tags[:role] || :research,
        task: tags[:task] || "test task"
      }})

    Map.merge(ctx, %{
      sub_agent: %{pid: pid, id: agent_id, task_id: task_id, parent_id: parent_id}
    })
  end

  def build_fixture(:registered_sub_agent, ctx, tags) do
    ctx = ensure_fixture(ctx, :event_collector, tags)

    agent_id = tags[:sub_agent_id] || "sub_#{ctx.unique_id}"
    task_id = get_in(ctx, [:parent_agent, :task_id]) || tags[:task_id] || "task_#{ctx.unique_id}"
    parent_id = get_in(ctx, [:parent_agent, :id]) || tags[:parent_agent_id] || "fake_parent"
    parent_pid = get_in(ctx, [:parent_agent, :pid]) || self()
    role = tags[:role] || :research

    {:ok, pid} =
      GenServer.start_link(
        AgentServer,
        {:sub_agent, %{
          agent_id: agent_id,
          task_id: task_id,
          tools: tags[:tools] || [],
          on_event: ctx.on_event,
          parent_agent_id: parent_id,
          parent_pid: parent_pid,
          role: role,
          task: tags[:task] || "test task"
        }},
        name: via_registry(agent_id, task_id, parent_id, role)
      )

    Map.merge(ctx, %{
      sub_agent: %{pid: pid, id: agent_id, task_id: task_id, parent_id: parent_id, registered: true}
    })
  end

  def build_fixture(:fake_sub_agent, ctx, tags) do
    sub_agent = %SubAgent{
      id: tags[:fake_sub_agent_id] || "sub_#{ctx.unique_id}",
      tool_call_id: tags[:tool_call_id] || "call_#{ctx.unique_id}",
      role: tags[:role] || :research,
      task: tags[:task] || "fake task",
      pid: self(),
      status: :running,
      started_at: System.monotonic_time(:millisecond)
    }

    Map.put(ctx, :fake_sub_agent, sub_agent)
  end

  def build_fixture(:tool_call, ctx, tags) do
    tool_call =
      ToolCall.new(
        tags[:tool_call_id] || "tool_#{ctx.unique_id}",
        tags[:tool_name] || "test_tool",
        tags[:tool_args] || "{}"
      )

    Map.put(ctx, :tool_call, tool_call)
  end

  # Ensure a dependency fixture exists
  defp ensure_fixture(ctx, fixture, tags) do
    key = fixture_key(fixture)

    if Map.has_key?(ctx, key) do
      ctx
    else
      build_fixture(fixture, ctx, tags)
    end
  end

  defp fixture_key(:event_collector), do: :on_event
  defp fixture_key(other), do: other

  defp via_registry(agent_id, task_id, parent_id, role) do
    {:via, Registry,
     {FrontmanServer.AgentRegistry, {:agent, agent_id},
      %{task_id: task_id, parent_agent_id: parent_id, role: role, state: :processing}}}
  end

  @doc "Cleanup agent processes"
  @spec cleanup_agents(map()) :: :ok
  def cleanup_agents(ctx) do
    [:parent_agent, :sub_agent]
    |> Enum.each(fn key ->
      case Map.get(ctx, key) do
        %{pid: pid} when is_pid(pid) ->
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)

        _ ->
          :ok
      end
    end)

    :ok
  end

  # State manipulation helpers

  @doc "Inject a sub-agent into parent's state"
  @spec inject_sub_agent(pid(), SubAgent.t()) :: :ok
  def inject_sub_agent(parent_pid, sub_agent) do
    :sys.replace_state(parent_pid, fn state ->
      agent = Agent.track_sub_agent(state.agent, sub_agent)
      %{state | agent: agent}
    end)

    :ok
  end

  @doc "Inject multiple sub-agents into parent's state"
  @spec inject_sub_agents(pid(), [SubAgent.t()]) :: :ok
  def inject_sub_agents(parent_pid, sub_agents) do
    :sys.replace_state(parent_pid, fn state ->
      agent =
        Enum.reduce(sub_agents, state.agent, fn sub, acc ->
          Agent.track_sub_agent(acc, sub)
        end)

      %{state | agent: agent}
    end)

    :ok
  end

  @doc "Inject a tool call into agent's state"
  @spec inject_tool_call(pid(), ToolCall.t()) :: :ok
  def inject_tool_call(agent_pid, tool_call) do
    :sys.replace_state(agent_pid, fn state ->
      agent = Agent.track_tool(state.agent, tool_call)
      %{state | agent: agent}
    end)

    :ok
  end

  @doc "Register a tool call for direct routing"
  @spec register_tool_call(String.t(), String.t()) :: {:ok, pid()} | {:error, term()}
  def register_tool_call(tool_call_id, agent_id) do
    Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}, agent_id)
  end

  @doc "Get agent state for inspection"
  @spec get_agent_state(pid()) :: map()
  def get_agent_state(pid) do
    :sys.get_state(pid)
  end

  # Factory functions for creating structs with defaults

  @doc "Create a SubAgent struct with optional overrides"
  @spec sub_agent_struct(keyword()) :: SubAgent.t()
  def sub_agent_struct(overrides \\ []) do
    unique = System.unique_integer([:positive])

    defaults = [
      id: "sub_#{unique}",
      tool_call_id: "call_#{unique}",
      role: :research,
      task: "test task",
      pid: self(),
      status: :running,
      started_at: System.monotonic_time(:millisecond)
    ]

    struct!(SubAgent, Keyword.merge(defaults, overrides))
  end

  @doc "Create a ToolCall struct with optional overrides"
  @spec tool_call_struct(keyword()) :: ToolCall.t()
  def tool_call_struct(overrides \\ []) do
    unique = System.unique_integer([:positive])

    id = Keyword.get(overrides, :id, "tool_#{unique}")
    name = Keyword.get(overrides, :name, "test_tool")
    args = Keyword.get(overrides, :args, "{}")

    ToolCall.new(id, name, args)
  end

  # Build llm_opts from context and tags for VCR fixture support
  # Note: fixture_path comes from tags (ExUnit context) via LLMIntegrationCase setup
  defp build_llm_opts(_ctx, tags) do
    case {tags[:fixture_path], tags[:llm_fixture]} do
      {path, _} when is_binary(path) ->
        # Fixture path from LLMIntegrationCase setup
        [fixture_path: path]

      {_, fixture_name} when is_binary(fixture_name) ->
        # Explicit fixture name via tag - use FixturePath to resolve
        path = ReqLLM.Test.FixturePath.for_explicit(fixture_name)
        [fixture_path: path]

      _ ->
        []
    end
  end
end
