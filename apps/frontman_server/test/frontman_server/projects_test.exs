defmodule FrontmanServer.ProjectsTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Projects

  alias FrontmanServer.Projects
  alias FrontmanServer.Projects.Project

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  describe "Project.repo_changeset/2" do
    test "valid with github_repo, default_branch, and user_id", %{scope: scope} do
      attrs = valid_project_attrs(%{"user_id" => scope.user.id})
      changeset = Project.repo_changeset(%Project{}, attrs)
      assert changeset.valid?
    end

    test "invalid without github_repo" do
      attrs = %{"default_branch" => "main", "user_id" => Ecto.UUID.generate()}
      changeset = Project.repo_changeset(%Project{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).github_repo
    end

    test "invalid without default_branch" do
      attrs = %{"github_repo" => "owner/repo", "user_id" => Ecto.UUID.generate()}
      changeset = Project.repo_changeset(%Project{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).default_branch
    end

    test "invalid without user_id" do
      attrs = %{"github_repo" => "owner/repo", "default_branch" => "main"}
      changeset = Project.repo_changeset(%Project{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "framework is optional" do
      attrs = %{
        "github_repo" => "owner/repo",
        "default_branch" => "main",
        "user_id" => Ecto.UUID.generate()
      }

      changeset = Project.repo_changeset(%Project{}, attrs)
      assert changeset.valid?
    end
  end

  describe "connect_repo/2" do
    test "creates a project for the scope's user", %{scope: scope} do
      attrs = valid_project_attrs()
      assert {:ok, project} = Projects.connect_repo(scope, attrs)
      assert project.user_id == scope.user.id
      assert project.github_repo == attrs["github_repo"]
      assert project.default_branch == attrs["default_branch"]
    end

    test "returns error changeset with invalid attrs", %{scope: scope} do
      assert {:error, changeset} = Projects.connect_repo(scope, %{})
      assert errors_on(changeset).github_repo
    end
  end

  describe "list_projects/1" do
    test "returns only projects owned by the scope's user", %{scope: scope} do
      project = project_fixture(scope)
      other_scope = user_scope_fixture()
      _other = project_fixture(other_scope)

      projects = Projects.list_projects(scope)
      assert length(projects) == 1
      assert hd(projects).id == project.id
    end

    test "returns empty list when user has no projects", %{scope: scope} do
      assert Projects.list_projects(scope) == []
    end
  end

  describe "get_project!/2" do
    test "returns the project for the correct user", %{scope: scope} do
      project = project_fixture(scope)
      assert Projects.get_project!(scope, project.id).id == project.id
    end

    test "raises for a project owned by a different user", %{scope: scope} do
      other_scope = user_scope_fixture()
      other_project = project_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(scope, other_project.id)
      end
    end
  end

  describe "get_project/2" do
    test "returns {:ok, project} for the correct user", %{scope: scope} do
      project = project_fixture(scope)
      assert {:ok, fetched} = Projects.get_project(scope, project.id)
      assert fetched.id == project.id
    end

    test "returns {:error, :not_found} for a project owned by a different user", %{scope: scope} do
      other_scope = user_scope_fixture()
      other_project = project_fixture(other_scope)
      assert {:error, :not_found} = Projects.get_project(scope, other_project.id)
    end
  end

  describe "record_analysis/3" do
    test "updates last_env_spec on the project", %{scope: scope} do
      project = project_fixture(scope)
      env_spec = %{"runtime" => "node20", "package_manager" => "pnpm"}

      assert {:ok, updated} = Projects.record_analysis(scope, project, env_spec)
      assert updated.last_env_spec == env_spec
    end

    test "returns {:error, :not_found} when project belongs to a different user", %{scope: scope} do
      other_scope = user_scope_fixture()
      other_project = project_fixture(other_scope)

      assert {:error, :not_found} = Projects.record_analysis(scope, other_project, %{})
    end
  end
end
