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
    field(:provider_ref, :string)
    field(:status, Ecto.Enum, values: [:provisioning, :running, :stopped, :error])
    field(:vm_ip, :string)
    field(:port_map, :map)
    field(:preview_url, :string)
    field(:env_spec, :map)
    field(:last_active_at, :utc_datetime)

    belongs_to(:task, FrontmanServer.Tasks.TaskSchema)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @doc """
  Changeset for provisioning a new sandbox.
  Status is always set to :provisioning on creation.
  System fields are set explicitly — never cast from user input.
  """
  @spec create_changeset(t(), Ecto.UUID.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(sandbox, task_id, attrs) do
    %{sandbox | task_id: task_id}
    |> cast(attrs, [:env_spec])
    |> put_change(:status, :provisioning)
    |> validate_required([:env_spec, :task_id])
    |> foreign_key_constraint(:task_id)
  end

  @doc """
  Changeset for updating sandbox status only.
  """
  @spec status_changeset(t(), :provisioning | :running | :stopped | :error) :: Ecto.Changeset.t()
  def status_changeset(sandbox, status)
      when status in [:provisioning, :running, :stopped, :error] do
    sandbox
    |> change(status: status)
    |> validate_required([:status])
  end

  @doc """
  Changeset for setting provider_ref after VM creation.
  """
  @spec set_provider_ref_changeset(t(), String.t()) :: Ecto.Changeset.t()
  def set_provider_ref_changeset(sandbox, provider_ref) do
    change(sandbox, provider_ref: provider_ref)
  end

  @doc """
  Changeset for updating last_active_at to now (second precision).
  """
  @spec touch_changeset(t()) :: Ecto.Changeset.t()
  def touch_changeset(sandbox) do
    change(sandbox, last_active_at: DateTime.utc_now(:second))
  end

  # Query helpers

  @spec by_id(Ecto.Queryable.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def by_id(query \\ __MODULE__, id) do
    from(s in query, where: s.id == ^id)
  end

  @spec for_user(Ecto.Queryable.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def for_user(query \\ __MODULE__, user_id) do
    from(s in query,
      join: t in assoc(s, :task),
      where: t.user_id == ^user_id
    )
  end

  @spec with_status(Ecto.Queryable.t(), atom() | [atom()]) :: Ecto.Query.t()
  def with_status(query \\ __MODULE__, status_or_statuses)

  def with_status(query, status) when is_atom(status) do
    from(s in query, where: s.status == ^status)
  end

  def with_status(query, statuses) when is_list(statuses) do
    from(s in query, where: s.status in ^statuses)
  end

  @spec for_task(Ecto.Queryable.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def for_task(query \\ __MODULE__, task_id) do
    from(s in query, where: s.task_id == ^task_id)
  end

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

  @spec idle_since(Ecto.Queryable.t(), DateTime.t()) :: Ecto.Query.t()
  def idle_since(query \\ __MODULE__, cutoff) do
    from(s in query,
      where: s.status == :running,
      where: s.last_active_at < ^cutoff or is_nil(s.last_active_at)
    )
  end
end
