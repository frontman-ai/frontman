defmodule FrontmanServer.Tasks.Execution.Framework do
  @moduledoc """
  Single source of truth for framework identity.

  Framework adapters (Next.js, Vite, Astro) each send a normalized ID on the
  client which flows through ACP into the server. This module canonicalizes
  those IDs into typed structs used for DB storage, prompt building, and
  feature-flag derivation.

  Unrecognized frameworks crash immediately — if we receive a value that isn't
  one of our known adapters, that's a bug in the adapter or a missing server
  mapping and we want to know about it loudly.

  ## Usage

      iex> Framework.from_client_label("nextjs")
      %Framework{id: :nextjs, display_name: "Next.js"}

      iex> Framework.to_string(%Framework{id: :nextjs, display_name: "Next.js"})
      "nextjs"

      iex> Framework.has_typescript_react?(%Framework{id: :nextjs, display_name: "Next.js"})
      true
  """

  use TypedStruct

  @type id :: :nextjs | :vite | :astro

  typedstruct enforce: true do
    @typedoc "Framework identity with display metadata"
    field(:id, id())
    field(:display_name, String.t())
  end

  # ── Constructors (private, build structs after typedstruct defines them) ──

  defp build(:nextjs), do: %__MODULE__{id: :nextjs, display_name: "Next.js"}
  defp build(:vite), do: %__MODULE__{id: :vite, display_name: "Vite"}
  defp build(:astro), do: %__MODULE__{id: :astro, display_name: "Astro"}

  # ── Public API ────────────────────────────────────────────────────────

  @doc """
  All known framework ids.
  """
  @spec known_ids() :: [id()]
  def known_ids, do: [:nextjs, :vite, :astro]

  @doc """
  Normalize a raw client string into a framework struct.

  Handles two forms:
  1. Normalized IDs (current clients): `"nextjs"`, `"vite"`, `"astro"`
  2. Legacy display labels: `"Next.js"`, `"Vite"`, `"Astro"`

  Raises on unrecognized input — if we get a framework value we don't know
  about, that's a bug that needs fixing, not silently swallowing.

      iex> Framework.from_client_label("nextjs")
      %Framework{id: :nextjs, display_name: "Next.js"}

      iex> Framework.from_client_label("Next.js")
      %Framework{id: :nextjs, display_name: "Next.js"}

      iex> Framework.from_client_label("VITE")
      %Framework{id: :vite, display_name: "Vite"}
  """
  @spec from_client_label(String.t()) :: t()
  def from_client_label(label) when is_binary(label) do
    case display_label_to_id(label) do
      nil -> label |> normalize_raw() |> slug_to_id() |> build()
      id -> build(id)
    end
  end

  @doc """
  Build a framework struct from a DB-stored string identifier.

  The DB stores normalized strings like `"nextjs"`. Raises on unrecognized
  values — if the DB contains garbage, that's a data integrity issue.

      iex> Framework.from_string("nextjs")
      %Framework{id: :nextjs, display_name: "Next.js"}
  """
  @spec from_string(String.t()) :: t()
  def from_string("nextjs"), do: build(:nextjs)
  def from_string("vite"), do: build(:vite)
  def from_string("astro"), do: build(:astro)

  @doc """
  Serialize a framework struct to the string stored in the database.

      iex> fw = Framework.from_string("nextjs")
      iex> Framework.to_string(fw)
      "nextjs"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{id: :nextjs}), do: "nextjs"
  def to_string(%__MODULE__{id: :vite}), do: "vite"
  def to_string(%__MODULE__{id: :astro}), do: "astro"

  # ── Feature flags ─────────────────────────────────────────────────────

  @doc """
  Whether the framework implies TypeScript + React tooling.

  Currently only Next.js.

      iex> fw = Framework.from_string("nextjs")
      iex> Framework.has_typescript_react?(fw)
      true

      iex> fw = Framework.from_string("vite")
      iex> Framework.has_typescript_react?(fw)
      false
  """
  @spec has_typescript_react?(t()) :: boolean()
  def has_typescript_react?(%__MODULE__{id: :nextjs}), do: true
  def has_typescript_react?(%__MODULE__{}), do: false

  # ── Internals ─────────────────────────────────────────────────────────

  # Exact display-label → id (case-sensitive, fast path for legacy clients)
  defp display_label_to_id("Next.js"), do: :nextjs
  defp display_label_to_id("Vite"), do: :vite
  defp display_label_to_id("Astro"), do: :astro
  defp display_label_to_id(_), do: nil

  # Defensive normalization: lowercase, strip non-alpha, then match.
  defp normalize_raw(label) do
    label
    |> String.downcase()
    |> String.replace(~r/[^a-z]/, "")
  end

  # Match the cleaned slug to a known id. No catch-all — crash on unknown.
  defp slug_to_id("nextjs"), do: :nextjs
  defp slug_to_id("vite"), do: :vite
  defp slug_to_id("astro"), do: :astro
end
