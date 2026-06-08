# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Frameworks do
  @moduledoc """
  Single source of truth for adapter framework identity.
  """

  use Boundary

  @catalog [
    %{
      id: :nextjs,
      stored_id: "nextjs",
      display_name: "Next.js",
      npm_package: "@frontman-ai/nextjs",
      load_project_context?: true,
      tool_execution_mode: :parallel,
      code_attachment_guidance?: true,
      framework_guidance_sections: [:nextjs]
    },
    %{
      id: :vite,
      stored_id: "vite",
      display_name: "Vite",
      npm_package: "@frontman-ai/vite",
      load_project_context?: true,
      tool_execution_mode: :parallel,
      code_attachment_guidance?: true,
      framework_guidance_sections: []
    },
    %{
      id: :astro,
      stored_id: "astro",
      display_name: "Astro",
      npm_package: "@frontman-ai/astro",
      load_project_context?: true,
      tool_execution_mode: :parallel,
      code_attachment_guidance?: true,
      framework_guidance_sections: [:astro]
    },
    %{
      id: :wordpress,
      stored_id: "wordpress",
      display_name: "WordPress",
      npm_package: nil,
      load_project_context?: false,
      tool_execution_mode: :serial,
      code_attachment_guidance?: false,
      framework_guidance_sections: [:wordpress]
    }
  ]

  @ids Enum.map(@catalog, &Map.fetch!(&1, :id))

  @doc "Returns all known framework ids."
  def ids, do: @ids

  @doc "Build a framework id from a DB-stored string identifier."
  def from_string(stored_id) when is_binary(stored_id) do
    stored_id
    |> record_by_stored_id!()
    |> Map.fetch!(:id)
  end

  @doc "Serialize a framework id to the string stored in the database."
  def to_string(id), do: id |> record_by_id!() |> Map.fetch!(:stored_id)

  @doc "Returns the display label for a known framework."
  def display_name(stored_id) when is_binary(stored_id) do
    stored_id
    |> record_by_stored_id!()
    |> Map.fetch!(:display_name)
  end

  @doc "Returns whether a signup framework id is canonical and allowed."
  def valid_signup_id?(stored_id) when is_binary(stored_id) do
    case find_by_stored_id(stored_id) do
      {:ok, _record} -> true
      :error -> false
    end
  end

  @doc "NPM adapter packages with registry version endpoints."
  def npm_packages do
    Enum.flat_map(@catalog, fn
      %{npm_package: nil} -> []
      %{npm_package: package} -> [package]
    end)
  end

  @doc "Returns whether MCP initialization should load project rules and structure."
  def load_project_context?(id) do
    id |> record_by_id!() |> Map.fetch!(:load_project_context?)
  end

  @doc "Runtime tool execution mode for framework sessions."
  def tool_execution_mode(id) do
    id |> record_by_id!() |> Map.fetch!(:tool_execution_mode)
  end

  @doc "Returns framework-specific prompt guidance sections."
  def framework_guidance_sections(nil), do: []

  def framework_guidance_sections(id) do
    id |> record_by_id!() |> Map.fetch!(:framework_guidance_sections)
  end

  @doc "Returns whether code-project attachment guidance should be included."
  def code_attachment_guidance?(nil), do: true

  def code_attachment_guidance?(id) do
    id |> record_by_id!() |> Map.fetch!(:code_attachment_guidance?)
  end

  @doc "Normalizes project trait values from runtime metadata."
  def normalize_project_traits(traits) when is_list(traits) do
    traits
    |> Enum.map(&project_trait!/1)
    |> Enum.uniq()
  end

  @doc """
  Extracts project traits from prompt metadata.

  Existing installed clients do not send `traits` yet. For that absent-key case,
  keep old Next.js TypeScript/React behavior. If the key exists, client value wins.
  """
  def project_traits_from_meta(%{} = meta, framework) do
    case Map.fetch(meta, "traits") do
      {:ok, traits} -> normalize_project_traits(traits)
      :error -> legacy_project_traits(framework)
    end
  end

  def project_traits_from_meta(nil, framework),
    do: legacy_project_traits(framework)

  defp legacy_project_traits(:nextjs), do: [:typescript, :react]
  defp legacy_project_traits(_framework), do: []

  defp project_trait!("typescript"), do: :typescript
  defp project_trait!("react"), do: :react
  defp project_trait!(:typescript), do: :typescript
  defp project_trait!(:react), do: :react

  defp project_trait!(trait) do
    raise ArgumentError, "unknown project trait: #{inspect(trait)}"
  end

  defp find_by_id(id), do: find_by(:id, id)
  defp find_by_stored_id(stored_id), do: find_by(:stored_id, stored_id)

  defp find_by(field, value) do
    case Enum.find(@catalog, &(Map.fetch!(&1, field) == value)) do
      nil -> :error
      record -> {:ok, record}
    end
  end

  defp record_by_id!(id) do
    case find_by_id(id) do
      {:ok, record} -> record
      :error -> raise ArgumentError, "unknown framework id: #{inspect(id)}"
    end
  end

  defp record_by_stored_id!(stored_id) do
    case find_by_stored_id(stored_id) do
      {:ok, record} -> record
      :error -> raise ArgumentError, "unknown framework id: #{inspect(stored_id)}"
    end
  end
end
