# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 -- see LICENSE for details.
# Additional terms apply -- see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.WriteFile do
  @moduledoc false

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Sandbox.Common

  @impl true
  def name, do: "write_file"

  @impl true
  def description do
    "Write text content to a file in the sandbox project, creating parent directories as needed."
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string"},
        "content" => %{"type" => "string"}
      },
      "required" => ["path", "content"]
    }
  end

  @impl true
  def timeout_ms, do: 120_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, context) do
    with {:ok, resolved} <- resolve_path(args),
         {:ok, content} <- fetch_content(args),
         :ok <- Common.write_file(context, resolved.absolute, content) do
      {:ok,
       %{
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

  defp fetch_content(%{"content" => content}) when is_binary(content), do: {:ok, content}
  defp fetch_content(_), do: {:error, "content is required"}
end
