defmodule FrontmanServer.Sandbox.Provider.MicrosandboxIntegrationTest do
  @moduledoc """
  Integration tests for the Microsandbox provider against a real `msb` CLI.

  These tests are excluded by default. Run with:

      mix test --include integration

  Requires `msb` to be installed and working on the host.
  """

  use ExUnit.Case

  @moduletag :integration

  alias FrontmanServer.Sandbox.EnvironmentSpec
  alias FrontmanServer.Sandbox.Provider.Microsandbox

  defp test_env_spec do
    {:ok, spec} =
      EnvironmentSpec.new(
        name: "integration-test-#{System.unique_integer([:positive])}",
        image: "ubuntu:24.04",
        devcontainer: %{},
        env: %{"SANDBOX_NAME" => "integration-test"}
      )

    spec
  end

  describe "full lifecycle" do
    test "create → exec → write_file → read_file → metrics → stop → start → destroy" do
      env_spec = test_env_spec()

      # Create
      assert {:ok, ref} = Microsandbox.create(env_spec)
      assert is_binary(ref)

      # Exec
      assert {:ok, %{exit_code: 0, stdout: stdout}} =
               Microsandbox.exec(ref, "echo", ["hello"], [])

      assert String.contains?(stdout, "hello")

      # Write file
      assert :ok = Microsandbox.write_file(ref, "/tmp/test.txt", "integration test content")

      # Read file
      assert {:ok, content} = Microsandbox.read_file(ref, "/tmp/test.txt")
      assert String.contains?(content, "integration test content")

      # Metrics
      assert {:ok, metrics} = Microsandbox.metrics(ref)
      assert metrics.status == "running"

      # Stop
      assert :ok = Microsandbox.stop(ref)

      # Start
      assert :ok = Microsandbox.start(ref)

      # Destroy
      assert :ok = Microsandbox.destroy(ref)
    end
  end
end
