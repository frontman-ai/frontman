# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Skill do
  @moduledoc "Loads current instructions from the backend skill catalog."

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Skills
  alias FrontmanServer.Tools.Backend.Context

  @impl true
  def name, do: "skill"

  @impl true
  def description do
    "Load instructions for an available skill. Pass its exact qualified name from the skill catalog."
  end

  @impl true
  def access, do: :read

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "name" => %{
          "type" => "string",
          "description" => "The exact qualified skill name, including the backend: prefix."
        }
      },
      "required" => ["name"]
    }
  end

  @impl true
  def timeout_ms, do: 30_000

  @impl true
  def execute(%{"name" => name}, %Context{scope: scope}) when is_binary(name) do
    case Skills.load(scope, name) do
      {:ok, skill} -> MCP.tool_result_text(skill.content)
      {:error, :not_found} -> MCP.tool_result_error("Skill not found: #{name}")
    end
  end

  def execute(_args, %Context{}), do: MCP.tool_result_error("name must be a string")
end
