# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 -- see LICENSE for details.
# Additional terms apply -- see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.ReadFile do
  @moduledoc false

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Sandbox.Common

  @impl true
  def name, do: "read_file"

  @impl true
  def description do
    "Read a file from the sandbox project. Returns content with line metadata for pagination."
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string"},
        "offset" => %{"type" => "integer", "default" => 0},
        "limit" => %{"type" => "integer", "default" => 500}
      },
      "required" => ["path"]
    }
  end

  @impl true
  def timeout_ms, do: 120_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, context) do
    with {:ok, resolved} <- resolve_path(args),
         {:ok, file_content} <- Common.run_strict(context, "cat", [resolved.absolute]) do
      offset = parse_non_negative_int(Map.get(args, "offset"), 0)
      limit = clamp_limit(Map.get(args, "limit"), 500)

      lines = String.split(file_content, "\n", trim: false)
      total_lines = length(lines)

      selected_lines =
        lines
        |> Enum.drop(offset)
        |> Enum.take(limit)

      has_more = offset + limit < total_lines

      {:ok,
       %{
         "content" => Enum.join(selected_lines, "\n"),
         "totalLines" => total_lines,
         "hasMore" => has_more,
         "_context" => %{
           "sourceRoot" => Common.project_root(),
           "resolvedPath" => resolved.absolute,
           "relativePath" => resolved.relative
         }
       }}
    end
  end

  defp resolve_path(%{"path" => path}), do: Common.resolve_relative_path(path)
  defp resolve_path(_), do: {:error, "path is required"}

  defp parse_non_negative_int(nil, default), do: default

  defp parse_non_negative_int(value, _default) when is_integer(value) and value >= 0,
    do: value

  defp parse_non_negative_int(_value, default), do: default

  defp clamp_limit(nil, default), do: default
  defp clamp_limit(value, _default) when is_integer(value) and value < 1, do: 1
  defp clamp_limit(value, _default) when is_integer(value) and value > 2_000, do: 2_000
  defp clamp_limit(value, _default) when is_integer(value), do: value
  defp clamp_limit(_value, default), do: default
end
