defmodule ReqLLM.Test.FixturePath do
  @moduledoc """
  Convention-based fixture path generation for LLM integration tests.

  Generates fixture paths from test module and test name, with support
  for explicit path overrides.

  ## Convention

  Paths follow the pattern:
    test/support/fixtures/llm/{module_name}/{test_name}.json

  ## Examples

      # Convention-based
      FixturePath.for_test(MyApp.AgentServerTest, "basic response")
      # => "test/support/fixtures/llm/agent_server_test/basic_response.json"

      # Explicit override
      FixturePath.for_explicit("custom/path/fixture.json")
      # => "test/support/fixtures/llm/custom/path/fixture.json"
  """

  @fixture_root "test/support/fixtures/llm"

  @doc """
  Generate fixture path from test module and test name.
  """
  @spec for_test(module(), atom() | String.t()) :: Path.t()
  def for_test(module, test_name) do
    module_part = module_to_path(module)
    test_part = test_to_path(test_name)
    Path.join([@fixture_root, module_part, "#{test_part}.json"])
  end

  @doc """
  Generate fixture path from explicit relative path.
  """
  @spec for_explicit(String.t()) :: Path.t()
  def for_explicit(path) do
    if String.ends_with?(path, ".json") do
      Path.join(@fixture_root, path)
    else
      Path.join(@fixture_root, "#{path}.json")
    end
  end

  @doc """
  Returns the fixture root directory.
  """
  @spec root() :: Path.t()
  def root, do: @fixture_root

  defp module_to_path(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp test_to_path(test_name) when is_atom(test_name) do
    test_to_path(Atom.to_string(test_name))
  end

  defp test_to_path(test_name) when is_binary(test_name) do
    test_name
    |> String.replace(~r/[^a-zA-Z0-9_\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.downcase()
    |> String.trim("_")
  end
end
