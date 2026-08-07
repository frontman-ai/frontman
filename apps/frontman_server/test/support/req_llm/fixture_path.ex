defmodule ReqLLM.Test.FixturePath do
  @fixture_root "test/support/fixtures/llm"

  def for_test(module, test_name) do
    module_part = module_to_path(module)
    test_part = test_to_path(test_name)
    Path.join([@fixture_root, module_part, "#{test_part}.json"])
  end

  def for_explicit(path) do
    if String.ends_with?(path, ".json") do
      Path.join(@fixture_root, path)
    else
      Path.join(@fixture_root, "#{path}.json")
    end
  end

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
