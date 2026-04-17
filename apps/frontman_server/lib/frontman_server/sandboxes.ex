defmodule FrontmanServer.Sandboxes do
  @moduledoc """
  Manages sandbox lifecycle — ephemeral development environments provisioned for tasks.

  Sandboxes are created against a project's repo and serve a specific task.
  Since work lives in git, sandboxes can be suspended and reprovisioned freely
  without losing any work.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Projects
  alias FrontmanServer.Repo
  alias FrontmanServer.Sandbox.EnvironmentSpec
  alias FrontmanServer.Sandbox.Orchestrator
  alias FrontmanServer.Sandboxes.Sandbox
  alias FrontmanServer.Tasks.TaskSchema

  @doc """
  Provisions a new sandbox for the given task and env_spec.

  Inserts the sandbox row in :provisioning status.
  The caller is responsible for wiring the result into any downstream state.
  """
  @spec provision_for_task(Scope.t(), TaskSchema.t(), map()) ::
          {:ok, Sandbox.t()} | {:error, :not_found | Ecto.Changeset.t() | term()}
  def provision_for_task(%Scope{} = scope, %TaskSchema{} = task, env_spec) do
    with {:ok, _project} <- Projects.get_project(scope, task.project_id),
         {:ok, persisted_env_spec} <- normalize_env_spec(env_spec) do
      %Sandbox{}
      |> Sandbox.create_changeset(task.id, task.project_id, %{env_spec: persisted_env_spec})
      |> Repo.insert()
    end
  end

  @doc """
  Returns the active sandbox for a task ID scoped to the user.

  Active means status is :provisioning or :running.
  """
  @spec current_for_task(Scope.t(), Ecto.UUID.t()) :: {:ok, Sandbox.t()} | {:error, :not_found}
  def current_for_task(%Scope{user: %{id: user_id}}, task_id) when is_binary(task_id) do
    query =
      Sandbox
      |> Sandbox.for_user(user_id)
      |> Sandbox.active_for_task(task_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      sandbox -> {:ok, sandbox}
    end
  end

  # Overload kept for existing callers that pass a `%TaskSchema{}`.
  @spec current_for_task(Scope.t(), TaskSchema.t()) ::
          Sandbox.t() | nil | {:error, :not_found}
  def current_for_task(%Scope{} = scope, %TaskSchema{} = task) do
    with {:ok, _project} <- Projects.get_project(scope, task.project_id) do
      case current_for_task(scope, task.id) do
        {:ok, sandbox} -> sandbox
        {:error, :not_found} -> nil
      end
    end
  end

  @doc "Get a sandbox by ID, scoped to the user."
  @spec get_sandbox(Scope.t(), Ecto.UUID.t()) :: {:ok, Sandbox.t()} | {:error, :not_found}
  def get_sandbox(%Scope{user: %{id: user_id}}, sandbox_id) do
    query =
      Sandbox
      |> Sandbox.by_id(sandbox_id)
      |> Sandbox.for_user(user_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      sandbox -> {:ok, sandbox}
    end
  end

  @doc "List all sandboxes for the user."
  @spec list_sandboxes(Scope.t()) :: {:ok, [Sandbox.t()]}
  def list_sandboxes(%Scope{user: %{id: user_id}}) do
    sandboxes =
      Sandbox
      |> Sandbox.for_user(user_id)
      |> Repo.all()

    {:ok, sandboxes}
  end

  @doc """
  Suspends a sandbox by setting its status to :stopped.
  Verifies ownership through the task owner.
  """
  @spec suspend(Scope.t(), Ecto.UUID.t()) ::
          {:ok, Sandbox.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def suspend(%Scope{} = scope, sandbox_id) do
    with {:ok, sandbox} <- get_sandbox(scope, sandbox_id) do
      sandbox
      |> Sandbox.status_changeset(:stopped)
      |> Repo.update()
    end
  end

  @doc """
  Permanently decommissions a sandbox by deleting its row.
  Verifies ownership through the task owner.
  """
  @spec decommission(Scope.t(), Ecto.UUID.t()) :: :ok | {:error, :not_found | Ecto.Changeset.t()}
  def decommission(%Scope{} = scope, sandbox_id) do
    with {:ok, sandbox} <- get_sandbox(scope, sandbox_id) do
      case Repo.delete(sandbox) do
        {:ok, _} -> :ok
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @doc """
  Provisions a sandbox and starts its Orchestrator GenServer.

  Requires `:task_id` in opts.
  """
  @spec provision_and_start(Scope.t(), map(), keyword()) :: {:ok, Sandbox.t()} | {:error, term()}
  def provision_and_start(%Scope{} = scope, env_spec, opts)
      when is_map(env_spec) and is_list(opts) do
    with {:ok, task_id} <- fetch_task_id(opts),
         {:ok, task} <- get_task(scope, task_id) do
      provision_and_start(scope, task, env_spec, opts)
    end
  end

  @doc """
  Provisions a sandbox and starts its Orchestrator GenServer.

  Inserts the DB row via `provision_for_task/3`, then starts the
  Orchestrator under the DynamicSupervisor. If the Orchestrator
  fails to start, marks the sandbox as :error.

  ## Options

    * `:provider` - provider module (defaults to app config)
    * `:heartbeat_interval_ms` - heartbeat interval (default 30_000)
    * `:provision_timeout_ms` - provisioning timeout (default 300_000)
  """
  @spec provision_and_start(Scope.t(), TaskSchema.t(), map(), keyword()) ::
          {:ok, Sandbox.t()} | {:error, term()}
  def provision_and_start(%Scope{} = scope, %TaskSchema{} = task, env_spec, opts \\ []) do
    with {:ok, sandbox} <- provision_for_task(scope, task, env_spec) do
      start_orchestrator(sandbox, opts)
    end
  end

  @doc "Execute a command in a running sandbox via the Orchestrator."
  @spec exec(Scope.t(), Ecto.UUID.t(), String.t(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def exec(%Scope{} = scope, sandbox_id, command, args, opts \\ []) do
    exec_in_sandbox(scope, sandbox_id, command, args, opts)
  end

  @doc "Execute a command in a running sandbox via the Orchestrator."
  @spec exec_in_sandbox(Scope.t(), Ecto.UUID.t(), String.t(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def exec_in_sandbox(%Scope{} = scope, sandbox_id, command, args, opts \\ []) do
    with {:ok, _sandbox} <- get_sandbox(scope, sandbox_id) do
      case Orchestrator.exec(sandbox_id, command, args, opts) do
        {:error, :not_found} -> {:error, :orchestrator_not_running}
        result -> result
      end
    end
  end

  @doc "Stop a running sandbox via the Orchestrator. The GenServer terminates."
  @spec stop_sandbox(Scope.t(), Ecto.UUID.t()) :: :ok | {:error, term()}
  def stop_sandbox(%Scope{} = scope, sandbox_id) do
    with {:ok, _sandbox} <- get_sandbox(scope, sandbox_id) do
      case Orchestrator.stop(sandbox_id) do
        {:error, :not_found} -> {:error, :orchestrator_not_running}
        result -> result
      end
    end
  end

  @doc "Destroy a sandbox and its VM via the Orchestrator."
  @spec destroy_sandbox(Scope.t(), Ecto.UUID.t()) :: :ok | {:error, term()}
  def destroy_sandbox(%Scope{} = scope, sandbox_id) do
    with {:ok, _sandbox} <- get_sandbox(scope, sandbox_id) do
      case Orchestrator.destroy(sandbox_id) do
        {:error, :not_found} -> {:error, :orchestrator_not_running}
        result -> result
      end
    end
  end

  defp fetch_task_id(opts) do
    case Keyword.fetch(opts, :task_id) do
      {:ok, task_id} -> {:ok, task_id}
      :error -> {:error, :task_id_required}
    end
  end

  defp get_task(%Scope{user: %{id: user_id}}, task_id) do
    query =
      TaskSchema
      |> TaskSchema.by_id(task_id)
      |> TaskSchema.for_user(user_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  defp start_orchestrator(sandbox, opts) do
    orchestrator_opts =
      Keyword.merge(
        [sandbox_id: sandbox.id],
        Keyword.take(opts, [
          :provider,
          :heartbeat_interval_ms,
          :provision_timeout_ms,
          :task_supervisor
        ])
      )

    case DynamicSupervisor.start_child(
           FrontmanServer.Sandbox.DynamicSupervisor,
           {Orchestrator, orchestrator_opts}
         ) do
      {:ok, _pid} ->
        {:ok, sandbox}

      {:error, reason} ->
        Logger.error(
          "[Sandboxes] failed to start Orchestrator for #{sandbox.id}: #{inspect(reason)}"
        )

        sandbox
        |> Sandbox.status_changeset(:error)
        |> Repo.update()

        {:error, reason}
    end
  end

  defp normalize_env_spec(env_spec) when is_map(env_spec) do
    case EnvironmentSpec.from_map(env_spec) do
      {:ok, spec} -> {:ok, EnvironmentSpec.to_map(spec)}
      {:error, reason} -> {:error, {:invalid_env_spec, reason}}
    end
  end

  defp normalize_env_spec(_env_spec), do: {:error, {:invalid_env_spec, :not_a_map}}
end
