defmodule FrontmanServer.Projects do
  @moduledoc """
  Manages projects — the unit connecting a GitHub repo to Frontman.
  Each project is owned by a user and provides the configuration context
  for tasks and sandboxes running against that repo.
  """

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Projects.Project
  alias FrontmanServer.Repo

  @doc """
  Returns a project by ID, raising if not found or not owned by the scope's user.
  """
  @spec get_project!(Scope.t(), Ecto.UUID.t()) :: Project.t()
  def get_project!(%Scope{user: user}, id) do
    Repo.get_by!(Project, id: id, user_id: user.id)
  end

  @doc """
  Returns a project by ID, or {:error, :not_found} if not found or not owned by the scope's user.
  """
  @spec get_project(Scope.t(), Ecto.UUID.t()) :: {:ok, Project.t()} | {:error, :not_found}
  def get_project(%Scope{user: user}, id) do
    case Repo.get_by(Project, id: id, user_id: user.id) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  @doc """
  Lists all projects belonging to the scope's user.
  """
  @spec list_projects(Scope.t()) :: [Project.t()]
  def list_projects(%Scope{user: user}) do
    Project
    |> Project.for_user(user.id)
    |> Repo.all()
  end

  @doc """
  Connects a GitHub repo to a new project for the scope's user.
  Requires github_repo and default_branch in attrs.
  """
  @spec connect_repo(Scope.t(), map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def connect_repo(%Scope{user: user}, attrs) do
    %Project{}
    |> Project.repo_changeset(user.id, attrs)
    |> Repo.insert()
  end

  @doc """
  Records the result of an environment analysis against the project's repo.
  Verifies the project belongs to the scope's user before updating.
  """
  @spec record_analysis(Scope.t(), Project.t(), map()) ::
          {:ok, Project.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def record_analysis(%Scope{} = scope, %Project{} = project, env_spec) do
    with {:ok, _owned} <- get_project(scope, project.id) do
      project
      |> Project.analysis_changeset(env_spec)
      |> Repo.update()
    end
  end
end
