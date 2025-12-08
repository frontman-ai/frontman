defmodule FrontmanServer.AgentCase do
  @moduledoc """
  Test case template for agent-related tests.

  Provides automatic fixture setup via tags and imports helper functions
  for state manipulation and assertions.

  ## Usage

      use FrontmanServer.AgentCase, async: true

      describe "some feature" do
        @tag fixtures: [:parent_agent]
        test "does something", %{parent_agent: %{pid: pid, id: id}} do
          # pid and id are available
        end

        @tag fixtures: [:parent_agent, :fake_sub_agent]
        test "with sub-agent", %{parent_agent: parent, fake_sub_agent: sub} do
          inject_sub_agent(parent.pid, sub)
          # ...
        end
      end

  ## Available fixtures

  - `:event_collector` - Creates `on_event` callback that sends to test process
  - `:parent_agent` - Starts a root agent, provides `%{pid, id, task_id}`
  - `:registered_parent_agent` - Same as above but registered with Registry
  - `:sub_agent` - Starts a sub-agent, provides `%{pid, id, task_id, parent_id}`
  - `:registered_sub_agent` - Same as above but registered with Registry
  - `:fake_sub_agent` - Creates a `SubAgent` struct (no process)
  - `:tool_call` - Creates a ToolCall struct

  ## Tag options

  You can customize fixtures via tags:

      @tag fixtures: [:parent_agent], parent_id: "custom_parent", task_id: "custom_task"
      @tag fixtures: [:sub_agent], role: :planning, task: "plan something"
      @tag fixtures: [:fake_sub_agent], fake_sub_agent_id: "specific_id"

  ## Helper functions

  The following helpers are imported automatically:

  - `inject_sub_agent/2` - Add SubAgent to parent state
  - `inject_sub_agents/2` - Add multiple SubAgents to parent state
  - `inject_tool_call/2` - Add tool call to agent state
  - `register_tool_call/2` - Register tool for direct routing
  - `get_agent_state/1` - Get agent's internal state
  - `sub_agent_struct/1` - Factory for SubAgent structs
  - `tool_call_struct/1` - Factory for ToolCall structs
  """

  use ExUnit.CaseTemplate

  alias FrontmanServer.Test.Fixtures.Agents, as: AgentFixtures

  using do
    quote do
      alias FrontmanServer.Agents.{Agent, AgentServer, SubAgent}
      import FrontmanServer.Test.Fixtures.Agents
    end
  end

  setup tags do
    fixtures = Map.get(tags, :fixtures, [])

    if Enum.empty?(fixtures) do
      :ok
    else
      ctx = AgentFixtures.build_fixtures(fixtures, tags)

      on_exit(fn ->
        AgentFixtures.cleanup_agents(ctx)
      end)

      {:ok, ctx}
    end
  end
end
