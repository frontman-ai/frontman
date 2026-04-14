defmodule FrontmanServer.Projects.Project do
  @moduledoc """
  A project connects a GitHub repo to Frontman and provides the context for all
  tasks and sandboxes. Every project is owned by a single user.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field :github_repo, :string
    field :default_branch, :string
    field :framework, :string
    field :last_env_spec, :map

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @doc """
  Changeset for connecting a GitHub repo to a new project.
  Requires github_repo and default_branch. user_id is set explicitly on the
  struct — never cast from user input.
  """
  @spec repo_changeset(t(), Ecto.UUID.t(), map()) :: Ecto.Changeset.t()
  def repo_changeset(project, user_id, attrs) do
    %{project | user_id: user_id}
    |> cast(attrs, [:github_repo, :default_branch, :framework])
    |> validate_required([:github_repo, :default_branch, :user_id])
    |> validate_length(:github_repo, min: 1)
    |> validate_length(:default_branch, min: 1)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for recording the result of a repo environment analysis.
  Only updates last_env_spec.
  """
  @spec analysis_changeset(t(), map()) :: Ecto.Changeset.t()
  def analysis_changeset(project, env_spec) do
    change(project, last_env_spec: env_spec)
  end

  # Query helpers

  @spec for_user(Ecto.Queryable.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def for_user(query \\ __MODULE__, user_id) do
    from(p in query, where: p.user_id == ^user_id)
  end
end
