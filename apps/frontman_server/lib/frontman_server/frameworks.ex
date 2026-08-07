defmodule FrontmanServer.Frameworks do
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

  def ids, do: @ids

  def from_string(stored_id) when is_binary(stored_id) do
    stored_id
    |> record_by_stored_id!()
    |> Map.fetch!(:id)
  end

  def to_string(id), do: id |> record_by_id!() |> Map.fetch!(:stored_id)

  def display_name(stored_id) when is_binary(stored_id) do
    stored_id
    |> record_by_stored_id!()
    |> Map.fetch!(:display_name)
  end

  def valid_signup_id?(stored_id) when is_binary(stored_id) do
    case find_by_stored_id(stored_id) do
      {:ok, _record} -> true
      :error -> false
    end
  end

  def npm_packages do
    Enum.flat_map(@catalog, fn
      %{npm_package: nil} -> []
      %{npm_package: package} -> [package]
    end)
  end

  def load_project_context?(id) do
    id |> record_by_id!() |> Map.fetch!(:load_project_context?)
  end

  def tool_execution_mode(id) do
    id |> record_by_id!() |> Map.fetch!(:tool_execution_mode)
  end

  def framework_guidance_sections(nil), do: []

  def framework_guidance_sections(id) do
    id |> record_by_id!() |> Map.fetch!(:framework_guidance_sections)
  end

  def code_attachment_guidance?(nil), do: true

  def code_attachment_guidance?(id) do
    id |> record_by_id!() |> Map.fetch!(:code_attachment_guidance?)
  end

  def normalize_project_traits(traits) when is_list(traits) do
    traits
    |> Enum.map(&project_trait!/1)
    |> Enum.uniq()
  end

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
