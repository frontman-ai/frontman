defmodule FrontmanServer.Test.Fixtures.Agents do
  @moduledoc """
  Reusable fixtures for agent-related tests.

  These fixtures are orthogonal to test cases - any test module can use them
  via the setup tag mechanism or by calling the functions directly.

  ## Usage with AgentCase

      use FrontmanServer.AgentCase, async: true

      @tag fixtures: [:event_collector]
      test "something", %{on_event: on_event} do
        # on_event callback sends to test process
      end

  ## Direct usage

      import FrontmanServer.Test.Fixtures.Agents

      setup do
        ctx = build_fixtures([:event_collector], %{})
        ctx
      end
  """

  alias ReqLLM.Test.FixturePath

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

  @doc """
  Cleanup any resources created by fixtures.

  Currently a no-op since existing fixtures don't create resources that need cleanup.
  """
  @spec cleanup_agents(map()) :: :ok
  def cleanup_agents(_ctx), do: :ok

  @doc "Build LLM options from context and tags for VCR fixture support"
  @spec build_llm_opts(map(), map()) :: keyword()
  def build_llm_opts(_ctx, tags) do
    case {tags[:fixture_path], tags[:llm_fixture]} do
      {path, _} when is_binary(path) ->
        # Fixture path from LLMIntegrationCase setup
        llm_model = infer_llm_model_from_fixture(path)
        opts = [fixture_path: path]
        if llm_model, do: Keyword.put(opts, :llm_model, llm_model), else: opts

      {_, fixture_name} when is_binary(fixture_name) ->
        # Explicit fixture name via tag - use FixturePath to resolve
        path = FixturePath.for_explicit(fixture_name)
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
