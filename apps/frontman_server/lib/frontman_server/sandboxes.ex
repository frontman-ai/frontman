defmodule FrontmanServer.Sandboxes do
  @moduledoc """
  Manages sandbox lifecycle — ephemeral development environments provisioned for tasks.

  Sandboxes are created against a project's repo and serve a specific task.
  Since work lives in git, sandboxes can be suspended and reprovisioned freely
  without losing any work.
  """

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Projects
  alias FrontmanServer.Repo
  alias FrontmanServer.Sandboxes.Sandbox
  alias FrontmanServer.Tasks.TaskSchema

  @doc """
  Provisions a new sandbox for the given task and env_spec.

  Inserts the sandbox row in :provisioning status.
  The caller is responsible for wiring the result into any downstream state.
  """
  @spec provision_for_task(Scope.t(), TaskSchema.t(), map()) ::
          {:ok, Sandbox.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def provision_for_task(%Scope{} = scope, %TaskSchema{} = task, env_spec) do
    with {:ok, _project} <- Projects.get_project(scope, task.project_id) do
      %Sandbox{}
      |> Sandbox.create_changeset(task.id, task.project_id, %{env_spec: env_spec})
      |> Repo.insert()
    end
  end

  @doc """
  Returns the currently active sandbox for the given task, or nil if none.

  Active means status is :provisioning or :running. A :stopped sandbox is not current.
  """
  @spec current_for_task(Scope.t(), TaskSchema.t()) ::
          Sandbox.t() | nil | {:error, :not_found}
  def current_for_task(%Scope{} = scope, %TaskSchema{} = task) do
    with {:ok, _project} <- Projects.get_project(scope, task.project_id) do
      Sandbox
      |> Sandbox.active_for_task(task.id)
      |> Repo.one()
    end
  end

  @doc """
  Suspends a sandbox by setting its status to :stopped.
  Verifies ownership through the sandbox's project.
  """
  @spec suspend(Scope.t(), Ecto.UUID.t()) ::
          {:ok, Sandbox.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def suspend(%Scope{} = scope, sandbox_id) do
    with {:ok, sandbox} <- get_sandbox(sandbox_id, scope) do
      sandbox
      |> Sandbox.status_changeset(:stopped)
      |> Repo.update()
    end
  end

  @doc """
  Permanently decommissions a sandbox by deleting its row.
  Verifies ownership through the sandbox's project.
  """
  @spec decommission(Scope.t(), Ecto.UUID.t()) :: :ok | {:error, :not_found | Ecto.Changeset.t()}
  def decommission(%Scope{} = scope, sandbox_id) do
    with {:ok, sandbox} <- get_sandbox(sandbox_id, scope) do
      case Repo.delete(sandbox) do
        {:ok, _} -> :ok
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  defp get_sandbox(sandbox_id, %Scope{} = scope) do
    with sandbox when not is_nil(sandbox) <- Repo.get(Sandbox, sandbox_id),
         {:ok, _project} <- Projects.get_project(scope, sandbox.project_id) do
      {:ok, sandbox}
    else
      nil -> {:error, :not_found}
      {:error, :not_found} -> {:error, :not_found}
    end
  end
end
