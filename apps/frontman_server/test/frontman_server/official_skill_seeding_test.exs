defmodule FrontmanServer.OfficialSkillSeedingTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Release
  alias FrontmanServer.Skills
  alias FrontmanServer.Skills.Skill
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  @tag :tmp_dir
  test "upserts by name and leaves unrelated skills and persisted snapshots unchanged", %{
    tmp_dir: directory
  } do
    scope = user_scope_fixture()
    path = Path.join(directory, "seed.md")

    File.write!(
      path,
      "---\nname: seed_skill\ndescription: Original description.\n---\nOriginal content."
    )

    assert :ok = Skills.seed_official!(directory)
    original = Repo.get_by!(Skill, name: "seed_skill")

    {:ok, unrelated} =
      Skills.register(scope, %{
        name: "unrelated_skill",
        description: "Keep this skill.",
        content: "Keep this content."
      })

    task = task_fixture(scope)

    {:ok, message} =
      Tasks.submit_user_message(
        scope,
        Map.merge(execution_request_fixture(), %{
          task_id: task.id,
          message_id: Ecto.UUID.generate(),
          message: user_content("Improve this page"),
          selected_server_skill_id: original.id
        })
      )

    skill_used =
      task.id
      |> interaction_changeset(%{
        id: Ecto.UUID.generate(),
        type: :skill_used,
        data: original |> Interaction.SkillUsed.build(message.id) |> Map.from_struct(),
        turn_number: 1
      })
      |> Repo.insert!()

    accepted = Repo.get!(InteractionSchema, message.id)
    assert accepted.data.selected_server_skill_content == original.content

    File.write!(
      path,
      "---\nname: seed_skill\ndescription: Updated description.\n---\nUpdated content."
    )

    assert :ok = Skills.seed_official!(directory)
    assert :ok = Skills.seed_official!(directory)

    updated = Repo.get_by!(Skill, name: original.name)
    assert updated.id == original.id
    assert updated.inserted_at == original.inserted_at
    assert updated.description == "Updated description."
    assert updated.content == "Updated content."
    assert Repo.aggregate(Skill, :count) == 2
    assert Repo.get!(Skill, unrelated.id) == unrelated
    assert Repo.get!(InteractionSchema, accepted.id) == accepted
    assert Repo.get!(InteractionSchema, skill_used.id) == skill_used

    File.rm!(path)
    assert :ok = Skills.seed_official!(directory)
    assert Repo.get!(Skill, original.id) == updated
  end

  @tag :tmp_dir
  test "malformed frontmatter and invalid skill fields raise", %{tmp_dir: directory} do
    path = Path.join(directory, "invalid.md")
    File.write!(path, "No frontmatter")

    assert_raise MatchError, fn -> Skills.seed_official!(directory) end

    File.write!(path, "---\nname: seed_skill\n---\nContent.")
    assert_raise KeyError, fn -> Skills.seed_official!(directory) end

    File.write!(path, "---\nname: invalid name\ndescription: Description.\n---\nContent.")
    assert_raise Ecto.InvalidChangesetError, fn -> Skills.seed_official!(directory) end
    assert Repo.aggregate(Skill, :count) == 0
  end

  test "release migration seeds every bundled skill without creating or confirming accounts" do
    assert Repo.aggregate(Skill, :count) == 0
    assert Repo.aggregate(User, :count) == 0

    Release.migrate()

    directory = Application.app_dir(:frontman_server, "priv/official_skills")

    expected_names =
      directory
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".md"))
      |> Enum.map(fn filename ->
        content = File.read!(Path.join(directory, filename))
        [_, name] = Regex.run(~r/^name: (.+)$/m, content)
        name
      end)
      |> Enum.sort()

    seeded = Skills.catalog(nil)
    assert Enum.map(seeded, & &1.name) == expected_names
    assert seeded != []
    assert Repo.aggregate(User, :count) == 0

    user = unconfirmed_user_fixture()
    assert user.confirmed_at == nil
    Release.migrate()
    assert Enum.map(Skills.catalog(nil), & &1.id) == Enum.map(seeded, & &1.id)
    assert Repo.all(User) == [user]
  end
end
