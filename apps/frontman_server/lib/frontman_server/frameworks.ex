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

      iex> Frameworks.has_typescript_react?(%Frameworks{id: :nextjs})
      true
  """

  use Boundary
  use TypedStruct

  @type id :: :nextjs | :vite | :astro | :wordpress
  @type stored_id :: String.t()

  @catalog [
    %{
      id: :nextjs,
      stored_id: "nextjs",
      display_name: "Next.js",
      npm_package: "@frontman-ai/nextjs",
      signup?: true,
      typescript_react?: true
    },
    %{
      id: :vite,
      stored_id: "vite",
      display_name: "Vite",
      npm_package: "@frontman-ai/vite",
      signup?: true,
      typescript_react?: false
    },
    %{
      id: :astro,
      stored_id: "astro",
      display_name: "Astro",
      npm_package: "@frontman-ai/astro",
      signup?: true,
      typescript_react?: false
    },
    %{
      id: :wordpress,
      stored_id: "wordpress",
      display_name: "WordPress",
      npm_package: nil,
      signup?: true,
      typescript_react?: false
    }
  ]

  typedstruct enforce: true do
    @typedoc "Framework identity"
    field(:id, id())
  end

  @doc """
  All known framework ids.
  """
  @spec known_ids() :: [id()]
  def known_ids, do: Enum.map(@catalog, & &1.id)

  @doc """
  Normalize a raw client string into a framework struct.

  Handles two forms:
  1. Normalized IDs (current clients): `"nextjs"`, `"vite"`, `"astro"`, `"wordpress"`
  2. Legacy display labels: `"Next.js"`, `"Vite"`, `"Astro"`, `"WordPress"`

  Raises on unrecognized input.

      iex> Frameworks.from_client_label("nextjs")
      %Frameworks{id: :nextjs}

      iex> Frameworks.from_client_label("Next.js")
      %Frameworks{id: :nextjs}
  """
  @spec from_client_label(String.t()) :: t()
  def from_client_label(label) when is_binary(label) do
    case find_by_stored_id(label) do
      {:ok, record} -> build(record)
      :error -> label |> record_by_client_display_label!() |> build()
    end
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
  @spec display_name(t() | stored_id()) :: String.t()
  def display_name(%__MODULE__{id: id}), do: id |> record_by_id!() |> Map.fetch!(:display_name)

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
      {:ok, record} -> Map.fetch!(record, :signup?)
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
  Whether the framework implies TypeScript + React tooling.

  Currently only Next.js.

      iex> fw = Frameworks.from_string("nextjs")
      iex> Frameworks.has_typescript_react?(fw)
      true

      iex> fw = Frameworks.from_string("vite")
      iex> Frameworks.has_typescript_react?(fw)
      false
  """
  @spec has_typescript_react?(t()) :: boolean()
  def has_typescript_react?(%__MODULE__{id: id}) do
    id
    |> record_by_id!()
    |> Map.fetch!(:typescript_react?)
  end

  defp build(%{id: id}), do: %__MODULE__{id: id}

  defp find_by_id(id), do: find_by(:id, id)
  defp find_by_stored_id(stored_id), do: find_by(:stored_id, stored_id)
  defp find_by_client_display_label(label), do: find_by(:display_name, label)

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

  defp record_by_client_display_label!(label) do
    case find_by_client_display_label(label) do
      {:ok, record} -> record
      :error -> raise ArgumentError, "unknown framework label: #{inspect(label)}"
    end
  end
end
