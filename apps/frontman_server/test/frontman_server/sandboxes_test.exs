defmodule FrontmanServer.SandboxesTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Repo
  alias FrontmanServer.Sandboxes
  alias FrontmanServer.Sandboxes.Sandbox

  setup do
    scope = user_scope_fixture()
    task = task_with_project_fixture(scope)
    %{scope: scope, task: task}
  end

  describe "provision_for_task/3" do
    test "creates a sandbox in provisioning status", %{scope: scope, task: task} do
      assert {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert sandbox.status == :provisioning
      assert sandbox.task_id == task.id
      assert sandbox.project_id == task.project_id
      assert sandbox.env_spec == valid_env_spec()
    end

    test "returns error changeset when env_spec is missing", %{scope: scope, task: task} do
      assert {:error, changeset} = Sandboxes.provision_for_task(scope, task, nil)
      assert errors_on(changeset).env_spec
    end

    test "returns {:error, :not_found} when task belongs to another user", %{task: task} do
      other_scope = user_scope_fixture()

      assert {:error, :not_found} =
               Sandboxes.provision_for_task(other_scope, task, valid_env_spec())
    end
  end

  describe "current_for_task/2" do
    test "returns nil when task has no active sandbox", %{scope: scope, task: task} do
      assert Sandboxes.current_for_task(scope, task) == nil
    end

    test "returns the sandbox after provisioning", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert fetched = Sandboxes.current_for_task(scope, task)
      assert fetched.id == sandbox.id
    end

    test "returns nil after sandbox is suspended", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      {:ok, _} = Sandboxes.suspend(scope, sandbox.id)
      assert Sandboxes.current_for_task(scope, task) == nil
    end

    test "returns {:error, :not_found} when task belongs to another user", %{
      scope: scope,
      task: task
    } do
      {:ok, _sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      other_scope = user_scope_fixture()
      assert {:error, :not_found} = Sandboxes.current_for_task(other_scope, task)
    end
  end

  describe "suspend/2" do
    test "sets sandbox status to :stopped", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert {:ok, suspended} = Sandboxes.suspend(scope, sandbox.id)
      assert suspended.status == :stopped
    end

    test "returns {:error, :not_found} for unknown sandbox_id", %{scope: scope} do
      assert {:error, :not_found} = Sandboxes.suspend(scope, Ecto.UUID.generate())
    end
  end

  describe "decommission/2" do
    test "deletes the sandbox row", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert :ok = Sandboxes.decommission(scope, sandbox.id)
      assert Repo.get(Sandbox, sandbox.id) == nil
    end

    test "decommissioned sandbox no longer appears as current", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      :ok = Sandboxes.decommission(scope, sandbox.id)
      assert Sandboxes.current_for_task(scope, task) == nil
    end

    test "returns {:error, :not_found} for unknown sandbox_id", %{scope: scope} do
      assert {:error, :not_found} = Sandboxes.decommission(scope, Ecto.UUID.generate())
    end
  end
end
