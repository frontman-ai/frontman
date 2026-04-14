defmodule FrontmanServer.SandboxesTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Sandboxes

  describe "sandboxes" do
    alias FrontmanServer.Sandboxes.Sandbox

    import FrontmanServer.SandboxesFixtures

    @invalid_attrs %{
      status: nil,
      provider_ref: nil,
      vm_ip: nil,
      port_map: nil,
      preview_url: nil,
      env_spec: nil,
      last_active_at: nil
    }

    test "list_sandboxes/0 returns all sandboxes" do
      sandbox = sandbox_fixture()
      assert Sandboxes.list_sandboxes() == [sandbox]
    end

    test "get_sandbox!/1 returns the sandbox with given id" do
      sandbox = sandbox_fixture()
      assert Sandboxes.get_sandbox!(sandbox.id) == sandbox
    end

    test "create_sandbox/1 with valid data creates a sandbox" do
      valid_attrs = %{
        status: "some status",
        provider_ref: "some provider_ref",
        vm_ip: "some vm_ip",
        port_map: %{},
        preview_url: "some preview_url",
        env_spec: %{},
        last_active_at: ~U[2026-04-13 10:48:00Z]
      }

      assert {:ok, %Sandbox{} = sandbox} = Sandboxes.create_sandbox(valid_attrs)
      assert sandbox.status == "some status"
      assert sandbox.provider_ref == "some provider_ref"
      assert sandbox.vm_ip == "some vm_ip"
      assert sandbox.port_map == %{}
      assert sandbox.preview_url == "some preview_url"
      assert sandbox.env_spec == %{}
      assert sandbox.last_active_at == ~U[2026-04-13 10:48:00Z]
    end

    test "create_sandbox/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sandboxes.create_sandbox(@invalid_attrs)
    end

    test "update_sandbox/2 with valid data updates the sandbox" do
      sandbox = sandbox_fixture()

      update_attrs = %{
        status: "some updated status",
        provider_ref: "some updated provider_ref",
        vm_ip: "some updated vm_ip",
        port_map: %{},
        preview_url: "some updated preview_url",
        env_spec: %{},
        last_active_at: ~U[2026-04-14 10:48:00Z]
      }

      assert {:ok, %Sandbox{} = sandbox} = Sandboxes.update_sandbox(sandbox, update_attrs)
      assert sandbox.status == "some updated status"
      assert sandbox.provider_ref == "some updated provider_ref"
      assert sandbox.vm_ip == "some updated vm_ip"
      assert sandbox.port_map == %{}
      assert sandbox.preview_url == "some updated preview_url"
      assert sandbox.env_spec == %{}
      assert sandbox.last_active_at == ~U[2026-04-14 10:48:00Z]
    end

    test "update_sandbox/2 with invalid data returns error changeset" do
      sandbox = sandbox_fixture()
      assert {:error, %Ecto.Changeset{}} = Sandboxes.update_sandbox(sandbox, @invalid_attrs)
      assert sandbox == Sandboxes.get_sandbox!(sandbox.id)
    end

    test "delete_sandbox/1 deletes the sandbox" do
      sandbox = sandbox_fixture()
      assert {:ok, %Sandbox{}} = Sandboxes.delete_sandbox(sandbox)
      assert_raise Ecto.NoResultsError, fn -> Sandboxes.get_sandbox!(sandbox.id) end
    end

    test "change_sandbox/1 returns a sandbox changeset" do
      sandbox = sandbox_fixture()
      assert %Ecto.Changeset{} = Sandboxes.change_sandbox(sandbox)
    end
  end
end
