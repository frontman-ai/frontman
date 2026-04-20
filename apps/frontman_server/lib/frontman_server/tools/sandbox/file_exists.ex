# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 -- see LICENSE for details.
# Additional terms apply -- see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.FileExists do
  @moduledoc false

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Sandbox.Common

  @impl true
  def name, do: "file_exists"

  @impl true
  def description, do: "Check whether a file or directory exists in the sandbox project."

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{"path" => %{"type" => "string"}},
      "required" => ["path"]
    }
  end

  @impl true
  def timeout_ms, do: 30_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, context) do
    with {:ok, resolved} <- resolve_path(args),
         {:ok, result} <- Common.run_bash_capture(context, exists_script(resolved.absolute)) do
      case result.exit_code do
        0 -> {:ok, true}
        1 -> {:ok, false}
        _ -> {:error, "Failed to check file existence: #{String.trim(result.stdout)}"}
      end
    end
  end

  defp resolve_path(%{"path" => path}), do: Common.resolve_relative_path(path)
  defp resolve_path(_), do: {:error, "path is required"}

  defp exists_script(absolute_path) do
    "[ -e " <> Common.shell_escape(absolute_path) <> " ]"
  end
end
