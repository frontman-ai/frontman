# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Frameworks do
  @moduledoc """
  Single source of truth for adapter framework identity.

  Framework adapters (Next.js, Vite, Astro, WordPress) each send a normalized
  ID on the client which flows through ACP into the server. This module
  canonicalizes those IDs into typed structs used for DB storage, prompt
  building, and policy derivation.

  Unrecognized frameworks crash immediately where they represent persisted or
  adapter data. If we receive a value that isn't one of our known adapters,
  that's a bug in the adapter or a missing server mapping.

  ## Usage

      iex> Frameworks.from_client_label("nextjs")
      %Frameworks{id: :nextjs}

      iex> Frameworks.to_string(%Frameworks{id: :nextjs})
      "nextjs"

      iex> Frameworks.normalize_project_traits(["typescript", "react"])
      [:typescript, :react]
  """

  use Boundary
  use TypedStruct

  @type id :: :nextjs | :vite | :astro | :wordpress
  @type stored_id :: String.t()
  @type mcp_initialization_step :: :load_agent_instructions | :list_tree
  @type project_trait :: :typescript | :react
  @type tool_execution_mode :: :parallel | :serial
  @type framework_guidance_section :: :nextjs | :astro | :wordpress

  @catalog [
    %{
      id: :nextjs,
      stored_id: "nextjs",
      display_name: "Next.js",
      npm_package: "@frontman-ai/nextjs",
      mcp_initialization_steps: [:load_agent_instructions, :list_tree],
      tool_execution_mode: :parallel,
      code_attachment_guidance?: true,
      framework_guidance_sections: [:nextjs]
    },
    %{
      id: :vite,
      stored_id: "vite",
      display_name: "Vite",
      npm_package: "@frontman-ai/vite",
      mcp_initialization_steps: [:load_agent_instructions, :list_tree],
      tool_execution_mode: :parallel,
      code_attachment_guidance?: true,
      framework_guidance_sections: []
    },
    %{
      id: :astro,
      stored_id: "astro",
      display_name: "Astro",
      npm_package: "@frontman-ai/astro",
      mcp_initialization_steps: [:load_agent_instructions, :list_tree],
      tool_execution_mode: :parallel,
      code_attachment_guidance?: true,
      framework_guidance_sections: [:astro]
    },
    %{
      id: :wordpress,
      stored_id: "wordpress",
      display_name: "WordPress",
      npm_package: nil,
      mcp_initialization_steps: [],
      tool_execution_mode: :serial,
      code_attachment_guidance?: false,
      framework_guidance_sections: [:wordpress]
    }
  ]

  typedstruct enforce: true do
    @typedoc "Framework identity"
    field(:id, id())
  end

  @doc """
  Normalize a raw client framework ID into a framework struct.

  Raises on unrecognized input.

      iex> Frameworks.from_client_label("nextjs")
      %Frameworks{id: :nextjs}
  """
  @spec from_client_label(String.t()) :: t()
  def from_client_label(label) when is_binary(label) do
    label
    |> record_by_stored_id!()
    |> build()
  end

  @doc """
  Build a framework struct from a DB-stored string identifier.

  The DB stores normalized strings like `"nextjs"`. Raises on unrecognized
  values. If the DB contains garbage, that's a data integrity issue.

      iex> Frameworks.from_string("nextjs")
      %Frameworks{id: :nextjs}
  """
  @spec from_string(stored_id()) :: t()
  def from_string(stored_id) when is_binary(stored_id) do
    stored_id
    |> record_by_stored_id!()
    |> build()
  end

  @doc """
  Serialize a framework struct to the string stored in the database.

      iex> fw = Frameworks.from_string("nextjs")
      iex> Frameworks.to_string(fw)
      "nextjs"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{id: id}), do: id |> record_by_id!() |> Map.fetch!(:stored_id)

  @doc """
  Returns the display label for a known framework.
  """
  @spec display_name(stored_id()) :: String.t()
  def display_name(stored_id) when is_binary(stored_id) do
    stored_id
    |> record_by_stored_id!()
    |> Map.fetch!(:display_name)
  end

  @doc """
  Returns whether a signup framework id is canonical and allowed.

  Signup URLs intentionally accept stored adapter ids only. Display labels like
  `"Next.js"` are rejected to keep OAuth session metadata canonical.
  """
  @spec valid_signup_id?(stored_id()) :: boolean()
  def valid_signup_id?(stored_id) when is_binary(stored_id) do
    case find_by_stored_id(stored_id) do
      {:ok, _record} -> true
      :error -> false
    end
  end

  @doc """
  NPM adapter packages with registry version endpoints.
  """
  @spec npm_packages() :: [String.t()]
  def npm_packages do
    Enum.flat_map(@catalog, fn
      %{npm_package: nil} -> []
      %{npm_package: package} -> [package]
    end)
  end

  @doc """
  MCP initialization steps required for each framework adapter.
  """
  @spec mcp_initialization_steps(t()) :: [mcp_initialization_step()]
  def mcp_initialization_steps(%__MODULE__{id: id}) do
    %{mcp_initialization_steps: steps} = record_by_id!(id)
    steps
  end

  @doc """
  Runtime tool execution mode for framework sessions.
  """
  @spec tool_execution_mode(t()) :: tool_execution_mode()
  def tool_execution_mode(%__MODULE__{id: id}) do
    id |> record_by_id!() |> Map.fetch!(:tool_execution_mode)
  end

  @doc """
  Returns framework-specific prompt guidance sections.
  """
  @spec framework_guidance_sections(t() | nil) :: [framework_guidance_section()]
  def framework_guidance_sections(nil), do: []

  def framework_guidance_sections(%__MODULE__{id: id}) do
    id |> record_by_id!() |> Map.fetch!(:framework_guidance_sections)
  end

  @doc """
  Returns whether code-project attachment guidance should be included.
  """
  @spec code_attachment_guidance?(t() | nil) :: boolean()
  def code_attachment_guidance?(nil), do: true

  def code_attachment_guidance?(%__MODULE__{id: id}) do
    id |> record_by_id!() |> Map.fetch!(:code_attachment_guidance?)
  end

  @doc """
  Normalizes project trait values from runtime metadata.
  """
  @spec normalize_project_traits([String.t() | project_trait()]) :: [project_trait()]
  def normalize_project_traits(traits) when is_list(traits) do
    traits
    |> Enum.map(&project_trait!/1)
    |> Enum.uniq()
  end

  @doc """
  Returns true when all required traits are present.
  """
  @spec has_project_traits?([project_trait()], [project_trait()]) :: boolean()
  def has_project_traits?(project_traits, required_traits)
      when is_list(project_traits) and is_list(required_traits) do
    project_trait_set = MapSet.new(project_traits)
    Enum.all?(required_traits, &MapSet.member?(project_trait_set, &1))
  end

  @doc """
  Extracts project traits from prompt metadata.

  Existing installed clients do not send `traits` yet. For that absent-key case,
  keep the old Next.js TypeScript/React behavior until runtime traits are wired.
  If the key exists, the client-provided value is authoritative.
  """
  @spec project_traits_from_meta(map() | nil, t()) :: [project_trait()]
  def project_traits_from_meta(%{} = meta, %__MODULE__{} = framework) do
    case Map.fetch(meta, "traits") do
      {:ok, traits} -> normalize_project_traits(traits)
      :error -> legacy_project_traits(framework)
    end
  end

  def project_traits_from_meta(nil, %__MODULE__{} = framework),
    do: legacy_project_traits(framework)

  defp build(%{id: id}), do: %__MODULE__{id: id}

  defp legacy_project_traits(%__MODULE__{id: :nextjs}), do: [:typescript, :react]
  defp legacy_project_traits(%__MODULE__{}), do: []

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
