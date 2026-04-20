# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 -- see LICENSE for details.
# Additional terms apply -- see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.Grep do
  @moduledoc false

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Sandbox.Common

  @impl true
  def name, do: "grep"

  @impl true
  def description do
    "Search file contents in the sandbox project and return matching lines grouped by file."
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "pattern" => %{"type" => "string"},
        "path" => %{"type" => "string"},
        "case_insensitive" => %{"type" => "boolean", "default" => false},
        "literal" => %{"type" => "boolean", "default" => false},
        "max_results" => %{"type" => "integer", "default" => 20}
      },
      "required" => ["pattern"]
    }
  end

  @impl true
  def timeout_ms, do: 120_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, context) do
    pattern = Map.get(args, "pattern")
    relative_path = Map.get(args, "path", ".")
    max_results = parse_max_results(Map.get(args, "max_results"))
    case_insensitive = Map.get(args, "case_insensitive", false) == true
    literal = Map.get(args, "literal", false) == true

    with {:ok, pattern} <- validate_pattern(pattern),
         {:ok, resolved} <- resolve_path(relative_path),
         {:ok, result} <- run_grep(context, resolved.absolute, pattern, case_insensitive, literal) do
      formatted = format_results(result.stdout, max_results)
      {:ok, formatted}
    end
  end

  defp validate_pattern(pattern) when is_binary(pattern) and pattern != "", do: {:ok, pattern}
  defp validate_pattern(_), do: {:error, "pattern is required"}

  defp parse_max_results(value) when is_integer(value) and value > 0 and value <= 200, do: value
  defp parse_max_results(_), do: 20

  defp resolve_path("."), do: {:ok, %{absolute: Common.project_root(), relative: "."}}
  defp resolve_path(path) when is_binary(path), do: Common.resolve_relative_path(path)
  defp resolve_path(_path), do: {:error, "path must be a string"}

  defp run_grep(context, absolute_path, pattern, case_insensitive, literal) do
    flags =
      []
      |> maybe_add_flag(case_insensitive, "-i")
      |> maybe_add_flag(literal, "-F")

    command =
      ["grep", "-RIn", "--binary-files=without-match", "--exclude-dir=.git"] ++
        flags ++ ["--", pattern, absolute_path]

    case Common.run(context, hd(command), tl(command), timeout_ms: timeout_ms()) do
      {:ok, %{exit_code: 0} = result} ->
        {:ok, result}

      {:ok, %{exit_code: 1}} ->
        {:ok, %{stdout: "", stderr: "", exit_code: 1}}

      {:ok, %{exit_code: exit_code, stdout: stdout, stderr: stderr}} ->
        {:error,
         "grep failed: exit_code=#{exit_code} stdout=#{String.trim(stdout)} stderr=#{String.trim(stderr)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_add_flag(flags, true, flag), do: flags ++ [flag]
  defp maybe_add_flag(flags, false, _flag), do: flags

  defp format_results("", _max_results) do
    %{"files" => [], "totalMatches" => 0, "truncated" => false}
  end

  defp format_results(stdout, max_results) do
    grouped =
      stdout
      |> String.split("\n", trim: true)
      |> Enum.reduce(%{}, &accumulate_match/2)

    files =
      grouped
      |> Enum.map(fn {path, matches} -> %{"path" => path, "matches" => matches} end)

    total_matches =
      files
      |> Enum.map(fn file -> length(file["matches"]) end)
      |> Enum.sum()

    %{
      "files" => Enum.take(files, max_results),
      "totalMatches" => total_matches,
      "truncated" => length(files) > max_results
    }
  end

  defp accumulate_match(line, acc) do
    case parse_line(line) do
      {:ok, file_path, line_num, line_text} ->
        add_grouped_match(acc, file_path, line_num, line_text)

      :error ->
        acc
    end
  end

  defp add_grouped_match(acc, file_path, line_num, line_text) do
    entry = %{"lineNum" => line_num, "lineText" => line_text}
    Map.update(acc, file_path, [entry], &append_entry(&1, entry))
  end

  defp append_entry(entries, entry), do: entries ++ [entry]

  defp parse_line(line) do
    case String.split(line, ":", parts: 3) do
      [file_path, line_num, line_text] ->
        case Integer.parse(line_num) do
          {value, ""} -> {:ok, file_path, value, line_text}
          _ -> :error
        end

      _ ->
        :error
    end
  end
end
