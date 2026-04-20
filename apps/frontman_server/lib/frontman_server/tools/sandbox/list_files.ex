# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 -- see LICENSE for details.
# Additional terms apply -- see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.ListFiles do
  @moduledoc false

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Sandbox.Common

  @impl true
  def name, do: "list_files"

  @impl true
  def description do
    "List immediate contents of a directory in the sandbox project."
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{"path" => %{"type" => "string"}}
    }
  end

  @impl true
  def timeout_ms, do: 60_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, context) do
    relative_path = Map.get(args, "path", ".")

    with {:ok, resolved} <- resolve_path(relative_path),
         {:ok, stdout} <-
           Common.run_bash(context, list_script(resolved.absolute), timeout_ms: timeout_ms()) do
      entries =
        stdout
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_line(&1, resolved.relative))

      {:ok, entries}
    end
  end

  defp resolve_path("."), do: {:ok, %{absolute: Common.project_root(), relative: "."}}
  defp resolve_path(path) when is_binary(path), do: Common.resolve_relative_path(path)
  defp resolve_path(_path), do: {:error, "path must be a string"}

  defp list_script(absolute_path) do
    quoted = Common.shell_escape(absolute_path)

    ~S"""
      if [ -f __QUOTED_PATH__ ]; then target=$(dirname __QUOTED_PATH__); else target=__QUOTED_PATH__; fi;
      for entry in "$target"/* "$target"/.*; do
        [ -e "$entry" ] || continue;
        name=$(basename "$entry");
        [ "$name" = '.' ] && continue;
        [ "$name" = '..' ] && continue;
        if [ -d "$entry" ]; then kind=d; else kind=f; fi;
        printf '%s\t%s\n' "$name" "$kind";
      done
    """
    |> String.replace("__QUOTED_PATH__", quoted)
    |> String.trim()
  end

  defp parse_line(line, base_relative) do
    case String.split(line, "\t", parts: 2) do
      [name, "d"] ->
        %{
          "name" => name,
          "path" => join_relative(base_relative, name),
          "isFile" => false,
          "isDirectory" => true
        }

      [name, _] ->
        %{
          "name" => name,
          "path" => join_relative(base_relative, name),
          "isFile" => true,
          "isDirectory" => false
        }

      _ ->
        %{
          "name" => line,
          "path" => join_relative(base_relative, line),
          "isFile" => true,
          "isDirectory" => false
        }
    end
  end

  defp join_relative(".", name), do: name
  defp join_relative(base, name), do: Path.join(base, name)
end
