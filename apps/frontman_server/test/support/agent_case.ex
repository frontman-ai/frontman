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
      end

  ## Available fixtures

  - `:event_collector` - Creates `on_event` callback that sends to test process
  - `:parent_agent` - Starts a root agent, provides `%{pid, id, task_id}`

  ## Tag options

  You can customize fixtures via tags:

      @tag fixtures: [:parent_agent], parent_id: "custom_parent", task_id: "custom_task"

  ## LLM Integration Tests (VCR-style fixtures)

  Tests that create agents with `:parent_agent` or similar fixtures automatically
  get VCR-style fixture support. Fixture paths are auto-generated based on
  module and test name:

      test/support/fixtures/llm/{module_name}/{test_name}.json

  Tests run normally using recorded cassettes. To record new fixtures:

      REQ_LLM_FIXTURES_MODE=record mix test

  Override fixture path with:

      @tag llm_fixture: "custom/path/to/fixture"
  """

  use ExUnit.CaseTemplate

  alias FrontmanServer.Test.Fixtures.Agents, as: AgentFixtures
  alias ReqLLM.Test.FixturePath

  using do
    quote do
      alias FrontmanServer.Agents.{Agent, AgentServer}
      import FrontmanServer.Test.Fixtures.Agents
    end
  end

  setup context do
    fixture_path = compute_fixture_path(context)
    fixtures = Map.get(context, :fixtures, [])

    if Enum.empty?(fixtures) do
      {:ok, fixture_path: fixture_path}
    else
      context_with_fixture = Map.put(context, :fixture_path, fixture_path)
      ctx = AgentFixtures.build_fixtures(fixtures, context_with_fixture)

      on_exit(fn ->
        AgentFixtures.cleanup_agents(ctx)
      end)

      {:ok, Map.put(ctx, :fixture_path, fixture_path)}
    end
  end

  @doc """
  Build LLM options with fixture support included (when available).

  Intended for tests that call ReqLLM directly and want to reuse the
  automatically computed `:fixture_path` from this case template.
  """
  @spec fixture_opts(map()) :: keyword()
  def fixture_opts(context) when is_map(context), do: fixture_opts(context, [])

  @spec fixture_opts(map(), keyword()) :: keyword()
  def fixture_opts(context, opts) when is_map(context) and is_list(opts) do
    case Map.get(context, :fixture_path) do
      path when is_binary(path) -> Keyword.merge([fixture_path: path], opts)
      _ -> opts
    end
  end

  @doc false
  defp compute_fixture_path(%{llm_fixture: explicit_path}) when is_binary(explicit_path) do
    FixturePath.for_explicit(explicit_path)
  end

  defp compute_fixture_path(%{module: module, test: test_name}) do
    FixturePath.for_test(module, test_name)
  end
end
