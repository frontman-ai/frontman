defmodule FrontmanServer.Test.Fixtures.Agents do
  @moduledoc """
  Reusable fixtures for agent-related tests.

  These fixtures are orthogonal to test cases - any test module can use them
  via the setup tag mechanism or by calling the functions directly.

  ## Usage with AgentCase

      use FrontmanServer.AgentCase, async: true

      @tag fixtures: [:parent_agent]
      test "something", %{parent_agent: parent} do
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

  alias FrontmanServer.Agents.AgentServer

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
      GenServer.start_link(
        AgentServer,
        {:root,
         %{
           agent_id: agent_id,
           task_id: task_id,
           tools: tags[:tools] || [],
           on_event: ctx.on_event,
           llm_opts: llm_opts
         }}
      )

    Map.merge(ctx, %{
      parent_agent: %{pid: pid, id: agent_id, task_id: task_id}
    })
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

  @doc "Cleanup agent processes"
  @spec cleanup_agents(map()) :: :ok
  def cleanup_agents(ctx) do
    [:parent_agent]
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

  # Build llm_opts from context and tags for VCR fixture support
  # Note: fixture_path comes from tags (ExUnit context) via LLMIntegrationCase setup
  defp build_llm_opts(_ctx, tags) do
    case {tags[:fixture_path], tags[:llm_fixture]} do
      {path, _} when is_binary(path) ->
        # Fixture path from LLMIntegrationCase setup
        llm_model = infer_llm_model_from_fixture(path)
        opts = [fixture_path: path]
        if llm_model, do: Keyword.put(opts, :llm_model, llm_model), else: opts

      {_, fixture_name} when is_binary(fixture_name) ->
        # Explicit fixture name via tag - use FixturePath to resolve
        path = ReqLLM.Test.FixturePath.for_explicit(fixture_name)
        llm_model = infer_llm_model_from_fixture(path)
        opts = [fixture_path: path]
        if llm_model, do: Keyword.put(opts, :llm_model, llm_model), else: opts

      _ ->
        []
    end
  end

  defp infer_llm_model_from_fixture(path) do
    # The fixture format stores:
    # - provider: "anthropic" | "openai" | ...
    # - model_spec: "claude-sonnet-4-20250514" (sometimes already prefixed)
    #
    # We want a model string like "anthropic:claude-sonnet-4-20250514" so the
    # correct provider parser is used during replay.
    with true <- File.exists?(path),
         {:ok, body} <- File.read(path),
         {:ok, json} <- Jason.decode(body),
         provider when is_binary(provider) <- Map.get(json, "provider"),
         model_spec when is_binary(model_spec) <- Map.get(json, "model_spec") do
      if String.contains?(model_spec, ":") do
        model_spec
      else
        "#{provider}:#{model_spec}"
      end
    else
      _ -> nil
    end
  end
end
