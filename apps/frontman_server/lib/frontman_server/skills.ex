# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Skills do
  @moduledoc "Catalogs globally usable Frontman skills."

  use Boundary,
    deps: [FrontmanServer],
    exports: [Skill]

  alias FrontmanServer.Repo
  alias FrontmanServer.Skills.Skill

  @doc "Upserts bundled official skills without changing IDs, unrelated skills, or task snapshots."
  def seed_official!(directory \\ Application.app_dir(:frontman_server, "priv/official_skills")) do
    directory
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.sort()
    |> Enum.each(fn filename ->
      content = File.read!(Path.join(directory, filename))
      ["", frontmatter, body] = String.split(content, "---", parts: 3)

      fields =
        frontmatter
        |> String.split("\n", trim: true)
        |> Map.new(fn line ->
          [key, value] = String.split(line, ":", parts: 2)
          {String.trim(key), String.trim(value)}
        end)

      %Skill{}
      |> Skill.changeset(%{
        name: Map.fetch!(fields, "name"),
        description: Map.fetch!(fields, "description"),
        content: String.trim(body)
      })
      |> Repo.insert!(
        on_conflict: {:replace, [:description, :content, :updated_at]},
        conflict_target: [:name]
      )
    end)
  end

  @doc "Returns all globally usable skills ordered by name."
  def catalog(_scope) do
    Skill
    |> Skill.ordered_by_name()
    |> Repo.all()
  end

  @doc "Gets a skill by database id."
  def get_by_id(_scope, nil), do: {:ok, nil}

  def get_by_id(_scope, id) when is_binary(id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Skill{} = skill <- Repo.get(Skill, id) do
      {:ok, skill}
    else
      _missing -> {:error, :not_found}
    end
  end

  def get_by_id(_scope, _id), do: {:error, :not_found}

  @doc "Registers a global skill."
  def register(_scope, attrs) do
    %Skill{}
    |> Skill.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a global skill."
  def update(_scope, %Skill{} = skill, attrs) do
    skill
    |> Skill.changeset(attrs)
    |> Repo.update()
  end
end
