defmodule FrontmanServer.AgentCase do
  use ExUnit.CaseTemplate

  alias ReqLLM.Test.FixturePath

  using do
    quote do
    end
  end

  setup context do
    fixture_path = compute_fixture_path(context)
    fixtures = Map.get(context, :fixtures, [])

    if Enum.empty?(fixtures) do
      {:ok, fixture_path: fixture_path}
    else
      {:ok, fixtures_context(fixtures, fixture_path)}
    end
  end

  def fixture_opts(context) when is_map(context), do: fixture_opts(context, [])

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

  defp fixtures_context([:event_collector], fixture_path) do
    test_pid = self()
    %{fixture_path: fixture_path, on_event: fn event -> send(test_pid, {:event, event}) end}
  end
end
