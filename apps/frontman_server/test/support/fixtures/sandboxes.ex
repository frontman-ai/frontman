defmodule FrontmanServer.Test.Fixtures.Sandboxes do
  @moduledoc "Test helpers for creating sandbox entities."

  import FrontmanServer.Test.Fixtures.Accounts, only: [user_scope_fixture: 0]
  import FrontmanServer.Test.Fixtures.Projects

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Sandboxes
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.TaskSchema

  def valid_env_spec do
    %{
      "name" => "test-sandbox",
      "image" => "ubuntu:24.04",
      "devcontainer" => %{
        "runtime" => "node20",
        "packageManager" => "pnpm",
        "forwardPorts" => [3000]
      },
      "env" => %{}
    }
  end

  def task_with_project_fixture(scope) do
    project = project_fixture(scope)
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id)

    TaskSchema
    |> Repo.get!(task_id)
    |> Ecto.Changeset.change(project_id: project.id)
    |> Repo.update!()
  end

  @doc """
  Insert a sandbox record and return it.

  Accepts either:

    * `sandbox_fixture(attrs)` - creates a fresh scope/task automatically
    * `sandbox_fixture(scope, attrs)` - uses an explicit scope
  """
  def sandbox_fixture(attrs \\ %{}) when is_map(attrs) do
    scope = Map.get(attrs, :scope, user_scope_fixture())
    sandbox_fixture(scope, attrs)
  end

  def sandbox_fixture(%Scope{} = scope, attrs) when is_map(attrs) do
    task = Map.get(attrs, :task, task_with_project_fixture(scope))
    env_spec = Map.get(attrs, :env_spec, valid_env_spec())

    {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, env_spec)

    maybe_update_sandbox(sandbox, attrs)
  end

  defp maybe_update_sandbox(sandbox, attrs) do
    updates =
      attrs
      |> Map.take([:provider_ref, :status, :vm_ip, :preview_url, :port_map, :last_active_at])

    if map_size(updates) == 0 do
      sandbox
    else
      sandbox
      |> Ecto.Changeset.change(updates)
      |> Repo.update!()
    end
  end
end
