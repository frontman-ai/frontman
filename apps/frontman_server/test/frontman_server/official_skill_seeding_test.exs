defmodule FrontmanServer.OfficialSkillSeedingTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Release
  alias FrontmanServer.Skills
  alias FrontmanServer.Skills.Skill

  import ExUnit.CaptureIO
  import FrontmanServer.Test.Fixtures.Accounts

  setup do
    previous_env = Application.fetch_env(:frontman_server, :env)
    Application.put_env(:frontman_server, :env, :prod)

    on_exit(fn ->
      case previous_env do
        {:ok, env} -> Application.put_env(:frontman_server, :env, env)
        :error -> Application.delete_env(:frontman_server, :env)
      end
    end)
  end

  test "release seeds are repeatable and update skills without touching accounts" do
    Release.migrate()
    original = Repo.get_by!(Skill, name: "design_polish")
    assert Repo.aggregate(User, :count) == 0
    skill_count = Repo.aggregate(Skill, :count)

    {:ok, _} = Skills.update(nil, original, %{description: "Outdated", content: "Outdated"})

    {:ok, unrelated} =
      Skills.register(nil, %{
        name: "unrelated_skill",
        description: "Keep this skill.",
        content: "Keep this content."
      })

    user = unconfirmed_user_fixture()
    Release.migrate()

    updated = Repo.get!(Skill, original.id)
    assert updated.description == original.description
    assert updated.content == original.content
    assert updated.inserted_at == original.inserted_at
    assert Repo.aggregate(Skill, :count) == skill_count + 1
    assert Repo.get!(Skill, unrelated.id) == unrelated
    assert Repo.all(User) == [user]
    assert user.confirmed_at == nil
  end

  test "development seeds create the development account only once" do
    Application.put_env(:frontman_server, :env, :dev)
    script = Application.app_dir(:frontman_server, "priv/repo/seeds.exs")

    capture_io(fn ->
      Code.eval_file(script)
      Code.eval_file(script)
    end)

    assert [%User{email: "dev@frontman.local", confirmed_at: confirmed_at}] = Repo.all(User)
    assert confirmed_at != nil
  end
end
