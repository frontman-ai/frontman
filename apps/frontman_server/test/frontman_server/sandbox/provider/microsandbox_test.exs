defmodule FrontmanServer.Sandbox.Provider.MicrosandboxTest do
  use ExUnit.Case, async: true

  import Mox

  alias FrontmanServer.Sandbox.EnvironmentSpec
  alias FrontmanServer.Sandbox.Provider.Microsandbox

  setup :verify_on_exit!

  defp valid_env_spec do
    {:ok, spec} =
      EnvironmentSpec.new(
        name: "test-sandbox",
        image: "ubuntu:24.04",
        devcontainer: %{"postCreateCommand" => "echo ready"}
      )

    spec
  end

  defp microsandbox(opts \\ []) do
    Keyword.put_new(opts, :command_runner, MockCommandRunner)
  end

  describe "create/1" do
    test "returns {:ok, name} when msb run succeeds" do
      env_spec = valid_env_spec()

      MockCommandRunner
      |> expect(:run, fn "msb", args, _opts ->
        assert "run" in args
        assert "--name" in args
        assert "test-sandbox" in args
        assert "--image" in args
        assert "ubuntu:24.04" in args
        {"Sandbox test-sandbox is running\n", 0}
      end)

      assert {:ok, "test-sandbox"} = Microsandbox.create(env_spec, microsandbox())
    end

    test "passes env vars as --env flags" do
      {:ok, spec} =
        EnvironmentSpec.new(
          name: "test-sandbox",
          image: "ubuntu:24.04",
          devcontainer: %{},
          env: %{"FOO" => "bar", "BAZ" => "qux"}
        )

      MockCommandRunner
      |> expect(:run, fn "msb", args, _opts ->
        env_args =
          Enum.filter(args, &String.starts_with?(&1, "FOO=")) ++
            Enum.filter(args, &String.starts_with?(&1, "BAZ="))

        assert env_args != [] or "--env" in args
        {"Sandbox test-sandbox is running\n", 0}
      end)

      assert {:ok, "test-sandbox"} = Microsandbox.create(spec, microsandbox())
    end

    test "returns error when msb run fails" do
      env_spec = valid_env_spec()

      MockCommandRunner
      |> expect(:run, fn "msb", _args, _opts ->
        {"Error: image not found\n", 1}
      end)

      assert {:error, {:cmd_failed, 1, "Error: image not found\n"}} =
               Microsandbox.create(env_spec, microsandbox())
    end
  end
end
