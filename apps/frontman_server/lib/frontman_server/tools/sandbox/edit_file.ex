# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 -- see LICENSE for details.
# Additional terms apply -- see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.EditFile do
  @moduledoc false

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Sandbox.Common

  @impl true
  def name, do: "edit_file"

  @impl true
  def description do
    "Edit a file by replacing oldText with newText. Set oldText to an empty string to create a new file."
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string"},
        "oldText" => %{"type" => "string"},
        "newText" => %{"type" => "string"},
        "replaceAll" => %{"type" => "boolean", "default" => false}
      },
      "required" => ["path", "oldText", "newText"]
    }
  end

  @impl true
  def timeout_ms, do: 120_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, context) do
    with {:ok, resolved} <- resolve_path(args),
         {:ok, old_text} <- fetch_old_text(args),
         {:ok, new_text} <- fetch_new_text(args),
         :ok <- validate_text_change(old_text, new_text),
         {:ok, current_content} <- read_existing_content(context, resolved.absolute, old_text),
         {:ok, updated_content} <- apply_edit(current_content, old_text, new_text, args),
         :ok <- Common.write_file(context, resolved.absolute, updated_content) do
      {:ok,
       %{
         "message" => "Edit applied successfully.",
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

  defp fetch_old_text(%{"oldText" => old_text}) when is_binary(old_text), do: {:ok, old_text}
  defp fetch_old_text(_), do: {:error, "oldText is required"}

  defp fetch_new_text(%{"newText" => new_text}) when is_binary(new_text), do: {:ok, new_text}
  defp fetch_new_text(_), do: {:error, "newText is required"}

  defp validate_text_change(old_text, new_text) do
    case old_text == new_text do
      true -> {:error, "oldText and newText must be different"}
      false -> :ok
    end
  end

  defp read_existing_content(_context, _absolute_path, ""), do: {:ok, ""}

  defp read_existing_content(context, absolute_path, _old_text) do
    Common.run_strict(context, "cat", [absolute_path])
  end

  defp apply_edit(_current_content, "", new_text, _args), do: {:ok, new_text}

  defp apply_edit(current_content, old_text, new_text, args) do
    replace_all = Map.get(args, "replaceAll", false) == true

    case String.contains?(current_content, old_text) do
      true ->
        updated =
          case replace_all do
            true -> String.replace(current_content, old_text, new_text)
            false -> String.replace(current_content, old_text, new_text, global: false)
          end

        {:ok, updated}

      false ->
        {:error, "oldText not found in file"}
    end
  end
end
