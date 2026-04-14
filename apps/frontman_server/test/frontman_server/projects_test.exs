defmodule FrontmanServer.ProjectsTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Projects

  describe "projects" do
    alias FrontmanServer.Projects.Project

    import FrontmanServer.ProjectsFixtures

    @invalid_attrs %{default_branch: nil, github_repo: nil, framework: nil, last_env_spec: nil}

    test "list_projects/0 returns all projects" do
      project = project_fixture()
      assert Projects.list_projects() == [project]
    end

    test "get_project!/1 returns the project with given id" do
      project = project_fixture()
      assert Projects.get_project!(project.id) == project
    end

    test "create_project/1 with valid data creates a project" do
      valid_attrs = %{
        default_branch: "some default_branch",
        github_repo: "some github_repo",
        framework: "some framework",
        last_env_spec: %{}
      }

      assert {:ok, %Project{} = project} = Projects.create_project(valid_attrs)
      assert project.default_branch == "some default_branch"
      assert project.github_repo == "some github_repo"
      assert project.framework == "some framework"
      assert project.last_env_spec == %{}
    end

    test "create_project/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Projects.create_project(@invalid_attrs)
    end

    test "update_project/2 with valid data updates the project" do
      project = project_fixture()

      update_attrs = %{
        default_branch: "some updated default_branch",
        github_repo: "some updated github_repo",
        framework: "some updated framework",
        last_env_spec: %{}
      }

      assert {:ok, %Project{} = project} = Projects.update_project(project, update_attrs)
      assert project.default_branch == "some updated default_branch"
      assert project.github_repo == "some updated github_repo"
      assert project.framework == "some updated framework"
      assert project.last_env_spec == %{}
    end

    test "update_project/2 with invalid data returns error changeset" do
      project = project_fixture()
      assert {:error, %Ecto.Changeset{}} = Projects.update_project(project, @invalid_attrs)
      assert project == Projects.get_project!(project.id)
    end

    test "delete_project/1 deletes the project" do
      project = project_fixture()
      assert {:ok, %Project{}} = Projects.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Projects.get_project!(project.id) end
    end

    test "change_project/1 returns a project changeset" do
      project = project_fixture()
      assert %Ecto.Changeset{} = Projects.change_project(project)
    end
  end
end
