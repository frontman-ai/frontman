defmodule FrontmanServer.Sandboxes.Sandbox do
  @moduledoc """
  Ecto schema for sandboxes — ephemeral development environments provisioned for tasks.

  A sandbox is created against a project's repo and serves a specific task.
  Work is preserved in git, so sandboxes can be freely suspended and reprovisioned.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sandboxes" do
    field :provider_ref, :string
    field :status, Ecto.Enum, values: [:provisioning, :running, :stopped, :error]
    field :vm_ip, :string
    field :port_map, :map
    field :preview_url, :string
    field :env_spec, :map
    field :last_active_at, :utc_datetime

    belongs_to :task, FrontmanServer.Tasks.TaskSchema
    belongs_to :project, FrontmanServer.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @doc """
  Changeset for provisioning a new sandbox.
  Status is always set to :provisioning on creation.
  System fields (task_id, project_id) are set explicitly — never cast from
  user input.
  """
  @spec create_changeset(t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(sandbox, task_id, project_id, attrs) do
    %{sandbox | task_id: task_id, project_id: project_id}
    |> cast(attrs, [:env_spec])
    |> put_change(:status, :provisioning)
    |> validate_required([:env_spec, :task_id, :project_id])
    |> foreign_key_constraint(:task_id)
    |> foreign_key_constraint(:project_id)
  end

  @doc """
  Changeset for updating sandbox status only.
  """
  @spec status_changeset(t(), atom()) :: Ecto.Changeset.t()
  def status_changeset(sandbox, status) do
    sandbox
    |> change(status: status)
    |> validate_required([:status])
  end

  # Query helpers

  @spec active_for_task(Ecto.Queryable.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def active_for_task(query \\ __MODULE__, task_id) do
    from(s in query,
      where: s.task_id == ^task_id and s.status in [:provisioning, :running],
      order_by: [desc: s.inserted_at],
      limit: 1
    )
  end

  @spec by_task(Ecto.Queryable.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def by_task(query \\ __MODULE__, task_id) do
    from(s in query, where: s.task_id == ^task_id)
  end
end
