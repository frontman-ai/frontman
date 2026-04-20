# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 -- see LICENSE for details.
# Additional terms apply -- see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.ListTree do
  @moduledoc false

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Sandbox.Common

  @impl true
  def name, do: "list_tree"

  @impl true
  def description do
    "Return a recursive directory tree rooted at the sandbox project or a given subdirectory."
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string"},
        "depth" => %{"type" => "integer", "default" => 3}
      }
    }
  end

  @impl true
  def timeout_ms, do: 90_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, context) do
    relative_path = Map.get(args, "path", ".")

    with {:ok, resolved} <- resolve_path(relative_path),
         {:ok, depth} <- parse_depth(Map.get(args, "depth")),
         {:ok, stdout} <-
           Common.run_bash(context, tree_script(resolved.absolute, depth),
             timeout_ms: timeout_ms()
           ) do
      tree_lines =
        stdout
        |> String.split("\n", trim: true)
        |> Enum.map(&decorate_tree_line/1)

      tree = ["." | tree_lines] |> Enum.join("\n")

      {:ok,
       %{
         "tree" => tree,
         "workspaces" => [],
         "monorepoType" => nil
       }}
    end
  end

  defp resolve_path("."), do: {:ok, %{absolute: Common.project_root(), relative: "."}}
  defp resolve_path(path) when is_binary(path), do: Common.resolve_relative_path(path)
  defp resolve_path(_path), do: {:error, "path must be a string"}

  defp parse_depth(nil), do: {:ok, 3}

  defp parse_depth(depth) when is_integer(depth) and depth > 0 and depth <= 10,
    do: {:ok, depth}

  defp parse_depth(_), do: {:error, "depth must be an integer between 1 and 10"}

  defp tree_script(absolute_path, depth) do
    escaped_path = Common.shell_escape(absolute_path)

    "find " <>
      escaped_path <>
      " -mindepth 1 -maxdepth " <>
      Integer.to_string(depth) <>
      " -printf '%P\t%y\n' | sort"
  end

  defp decorate_tree_line(line) do
    case String.split(line, "\t", parts: 2) do
      [path, "d"] -> "|- " <> path <> "/"
      [path, _] -> "|- " <> path
      _ -> "|- " <> line
    end
  end
end
