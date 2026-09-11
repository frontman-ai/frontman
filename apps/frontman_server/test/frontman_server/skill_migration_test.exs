defmodule FrontmanServer.SkillMigrationTest do
  use FrontmanServer.DataCase

  alias Ecto.Migration.Runner
  alias FrontmanServer.Repo.Migrations.AddDesignPolishSkill
  alias FrontmanServer.Skills
  alias FrontmanServer.Skills.Skill

  test "rollback removes the inserted skill but preserves a pre-existing same-name row" do
    Code.require_file("priv/repo/migrations/20260911000000_add_design_polish_skill.exs")
    Repo.delete_all(Skill)

    assert :ok = run_migration(:up)
    original = Repo.get_by!(Skill, name: "design_polish")
    assert :ok = run_migration(:down)
    assert Repo.get(Skill, original.id) == nil

    assert :ok = run_migration(:up)
    assert Repo.get_by!(Skill, name: "design_polish").id == original.id
    assert :ok = run_migration(:down)

    {:ok, existing} =
      Skills.register(nil, %{
        name: "design_polish",
        description: "Existing skill.",
        content: "Keep these instructions."
      })

    assert :ok = run_migration(:up)
    assert Repo.get_by!(Skill, name: "design_polish") == existing
    assert :ok = run_migration(:down)
    assert Repo.get_by!(Skill, name: "design_polish") == existing
  end

  defp run_migration(direction) do
    Runner.run(
      Repo,
      Repo.config(),
      0,
      AddDesignPolishSkill,
      :forward,
      direction,
      direction,
      log: false
    )
  end
end
