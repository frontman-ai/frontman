defmodule FrontmanServer.SkillsTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Skills
  alias FrontmanServer.Skills.Skill

  import FrontmanServer.Test.Fixtures.Accounts

  describe "register/2" do
    test "registers a global skill and downcases its name" do
      scope = user_scope_fixture()

      assert {:ok, %Skill{} = skill} =
               Skills.register(scope, %{
                 name: "Design_Polish",
                 description: "Improve visual quality.",
                 content: "Use stronger hierarchy."
               })

      assert skill.name == "design_polish"
      assert skill.description == "Improve visual quality."
      assert skill.content == "Use stronger hierarchy."
    end

    test "validates required fields" do
      scope = user_scope_fixture()

      assert {:error, changeset} = Skills.register(scope, %{})

      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).description
      assert "can't be blank" in errors_on(changeset).content
    end

    test "validates name format" do
      scope = user_scope_fixture()

      assert {:error, changeset} =
               Skills.register(scope, %{
                 name: "bad name",
                 description: "Invalid skill.",
                 content: "Invalid content."
               })

      assert "has invalid format" in errors_on(changeset).name
    end

    test "validates description length" do
      scope = user_scope_fixture()

      assert {:error, changeset} =
               Skills.register(
                 scope,
                 valid_skill_attrs(%{description: String.duplicate("a", 201)})
               )

      assert "should be at most 200 character(s)" in errors_on(changeset).description
    end

    test "enforces unique names" do
      scope = user_scope_fixture()
      attrs = valid_skill_attrs(%{name: "seo_auditor"})

      assert {:ok, _skill} = Skills.register(scope, attrs)
      assert {:error, changeset} = Skills.register(scope, attrs)

      assert "has already been taken" in errors_on(changeset).name
    end
  end

  describe "catalog/1" do
    test "returns globally usable skills ordered by name" do
      scope = user_scope_fixture()

      {:ok, _} = Skills.register(scope, valid_skill_attrs(%{name: "seo_auditor"}))
      {:ok, _} = Skills.register(scope, valid_skill_attrs(%{name: "design_polish"}))

      assert [%Skill{name: "design_polish"}, %Skill{name: "seo_auditor"}] =
               Skills.catalog(scope)
    end
  end

  describe "get_by_id/2" do
    test "returns ok tuple for an existing database id" do
      scope = user_scope_fixture()
      {:ok, skill} = Skills.register(scope, valid_skill_attrs())

      assert {:ok, %Skill{id: skill_id}} = Skills.get_by_id(scope, skill.id)
      assert skill_id == skill.id
    end

    test "returns not_found for a missing database id" do
      scope = user_scope_fixture()

      assert {:error, :not_found} = Skills.get_by_id(scope, Ecto.UUID.generate())
    end

    test "returns not_found for invalid ids" do
      scope = user_scope_fixture()

      assert {:error, :not_found} = Skills.get_by_id(scope, "not-a-uuid")
      assert {:error, :not_found} = Skills.get_by_id(scope, 123)
    end
  end

  describe "update/3" do
    test "updates through the skill changeset" do
      scope = user_scope_fixture()
      {:ok, skill} = Skills.register(scope, valid_skill_attrs())

      assert {:ok, updated} = Skills.update(scope, skill, %{description: "Updated skill."})

      assert updated.description == "Updated skill."
    end
  end

  defp valid_skill_attrs(attrs \\ %{}) do
    Map.merge(
      %{
        name: "conversion_copy",
        description: "Rewrite page copy for conversion.",
        content: "Focus on user intent and clear CTAs."
      },
      attrs
    )
  end
end
