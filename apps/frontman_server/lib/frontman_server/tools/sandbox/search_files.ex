# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 -- see LICENSE for details.
# Additional terms apply -- see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.SearchFiles do
  @moduledoc false

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Sandbox.Common

  @impl true
  def name, do: "search_files"

  @impl true
  def description do
    "Search for files by filename pattern in the sandbox project."
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "pattern" => %{"type" => "string"},
        "path" => %{"type" => "string"},
        "max_results" => %{"type" => "integer", "default" => 20}
      },
      "required" => ["pattern"]
    }
  end

  @impl true
  def timeout_ms, do: 90_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, context) do
    pattern = Map.get(args, "pattern")
    max_results = parse_max_results(Map.get(args, "max_results"))
    relative_path = Map.get(args, "path", ".")

    with {:ok, pattern} <- validate_pattern(pattern),
         {:ok, resolved} <- resolve_path(relative_path),
         {:ok, stdout} <-
           Common.run_bash(context, search_script(resolved.absolute), timeout_ms: timeout_ms()) do
      matches =
        stdout
        |> String.split("\n", trim: true)
        |> Enum.filter(&matches_pattern?(Path.basename(&1), pattern))

      total_results = length(matches)
      files = Enum.take(matches, max_results)

      {:ok,
       %{
         "files" => files,
         "totalResults" => total_results,
         "truncated" => total_results > max_results
       }}
    end
  end

  defp validate_pattern(pattern) when is_binary(pattern) and pattern != "", do: {:ok, pattern}
  defp validate_pattern(_), do: {:error, "pattern is required"}

  defp parse_max_results(value) when is_integer(value) and value > 0 and value <= 200, do: value
  defp parse_max_results(_), do: 20

  defp resolve_path("."), do: {:ok, %{absolute: Common.project_root(), relative: "."}}
  defp resolve_path(path) when is_binary(path), do: Common.resolve_relative_path(path)
  defp resolve_path(_path), do: {:error, "path must be a string"}

  defp search_script(absolute_path) do
    "find " <> Common.shell_escape(absolute_path) <> " -type f -printf '%P\n'"
  end

  defp matches_pattern?(filename, pattern) do
    normalized_pattern = String.downcase(pattern)
    normalized_filename = String.downcase(filename)

    case wildcard_pattern?(normalized_pattern) do
      true -> wildcard_match?(normalized_filename, normalized_pattern)
      false -> String.contains?(normalized_filename, normalized_pattern)
    end
  end

  defp wildcard_pattern?(pattern) do
    String.contains?(pattern, ["*", "?"])
  end

  defp wildcard_match?(filename, pattern) do
    regex =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")
      |> String.replace("\\?", ".")

    Regex.match?(Regex.compile!("^" <> regex <> "$"), filename)
  end
end
