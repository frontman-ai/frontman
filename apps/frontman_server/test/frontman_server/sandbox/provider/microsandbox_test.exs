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

  describe "exec/4" do
    test "returns {:ok, exec_result} on success" do
      MockCommandRunner
      |> expect(:run, fn "msb", args, _opts ->
        assert args == ["exec", "sb-abc123", "--", "echo", "hello"]
        {"hello\n", 0}
      end)

      assert {:ok, %{exit_code: 0, stdout: "hello\n", stderr: ""}} =
               Microsandbox.exec("sb-abc123", "echo", ["hello"], microsandbox())
    end

    test "returns exec_result with non-zero exit code (command ran but failed)" do
      MockCommandRunner
      |> expect(:run, fn "msb", _args, _opts ->
        {"test failed\n", 0}
      end)

      assert {:ok, %{exit_code: 0, stdout: "test failed\n"}} =
               Microsandbox.exec("sb-abc123", "mix", ["test"], microsandbox())
    end

    test "passes timeout_ms from opts" do
      MockCommandRunner
      |> expect(:run, fn "msb", _args, opts ->
        assert Keyword.get(opts, :timeout) == 300_000
        {"", 0}
      end)

      assert {:ok, _} =
               Microsandbox.exec(
                 "sb-abc123",
                 "mix",
                 ["test"],
                 microsandbox(timeout_ms: 300_000)
               )
    end

    test "returns error when msb exec fails" do
      MockCommandRunner
      |> expect(:run, fn "msb", _args, _opts ->
        {"Error: sandbox not found\n", 1}
      end)

      assert {:error, {:cmd_failed, 1, _}} =
               Microsandbox.exec("sb-abc123", "false", [], microsandbox())
    end
  end

  describe "metrics/1" do
    test "returns {:ok, sandbox_metrics} on success" do
      json_output =
        Jason.encode!([
          %{
            "name" => "sb-abc123",
            "status" => "running",
            "cpu_percent" => 12.5,
            "memory_bytes" => 268_435_456
          },
          %{
            "name" => "other-sandbox",
            "status" => "stopped",
            "cpu_percent" => 0.0,
            "memory_bytes" => 0
          }
        ])

      MockCommandRunner
      |> expect(:run, fn "msb", ["list", "--json"], _opts ->
        {json_output, 0}
      end)

      assert {:ok, metrics} = Microsandbox.metrics("sb-abc123", microsandbox())
      assert metrics.status == "running"
      assert metrics.cpu_percent == 12.5
      assert metrics.memory_bytes == 268_435_456
    end

    test "returns error when sandbox not found in list" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["list", "--json"], _opts ->
        {Jason.encode!([
           %{"name" => "other", "status" => "running", "cpu_percent" => 0.0, "memory_bytes" => 0}
         ]), 0}
      end)

      assert {:error, :not_found} = Microsandbox.metrics("sb-abc123", microsandbox())
    end

    test "returns error when msb list fails" do
      MockCommandRunner
      |> expect(:run, fn "msb", _args, _opts ->
        {"Error: daemon unreachable\n", 1}
      end)

      assert {:error, {:cmd_failed, 1, _}} = Microsandbox.metrics("sb-abc123", microsandbox())
    end
  end

  describe "stop/1" do
    test "returns :ok on success" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["stop", "sb-abc123"], _opts ->
        {"Sandbox sb-abc123 stopped\n", 0}
      end)

      assert :ok = Microsandbox.stop("sb-abc123", microsandbox())
    end

    test "returns error on failure" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["stop", "sb-abc123"], _opts ->
        {"Error: not running\n", 1}
      end)

      assert {:error, {:cmd_failed, 1, _}} = Microsandbox.stop("sb-abc123", microsandbox())
    end
  end

  describe "start/1" do
    test "returns :ok on success" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["start", "sb-abc123"], _opts ->
        {"Sandbox sb-abc123 started\n", 0}
      end)

      assert :ok = Microsandbox.start("sb-abc123", microsandbox())
    end
  end

  describe "destroy/1" do
    test "returns :ok when stop + remove both succeed" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["stop", "sb-abc123"], _opts ->
        {"Stopped\n", 0}
      end)
      |> expect(:run, fn "msb", ["remove", "sb-abc123"], _opts ->
        {"Removed\n", 0}
      end)

      assert :ok = Microsandbox.destroy("sb-abc123", microsandbox())
    end

    test "returns :ok when stop fails (already stopped) but remove succeeds" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["stop", "sb-abc123"], _opts ->
        {"Error: not running\n", 1}
      end)
      |> expect(:run, fn "msb", ["remove", "sb-abc123"], _opts ->
        {"Removed\n", 0}
      end)

      assert :ok = Microsandbox.destroy("sb-abc123", microsandbox())
    end

    test "returns error when remove fails" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["stop", "sb-abc123"], _opts ->
        {"Stopped\n", 0}
      end)
      |> expect(:run, fn "msb", ["remove", "sb-abc123"], _opts ->
        {"Error: sandbox not found\n", 1}
      end)

      assert {:error, {:cmd_failed, 1, _}} = Microsandbox.destroy("sb-abc123", microsandbox())
    end
  end

  describe "read_file/2" do
    test "returns {:ok, content} by executing cat inside the sandbox" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["exec", "sb-abc123", "--", "cat", "/app/README.md"], _opts ->
        {"# Hello\n", 0}
      end)

      assert {:ok, "# Hello\n"} =
               Microsandbox.read_file("sb-abc123", "/app/README.md", microsandbox())
    end

    test "returns error when file not found" do
      MockCommandRunner
      |> expect(:run, fn "msb", _args, _opts ->
        {"cat: /app/nope.txt: No such file or directory\n", 1}
      end)

      assert {:error, {:cmd_failed, 1, _}} =
               Microsandbox.read_file("sb-abc123", "/app/nope.txt", microsandbox())
    end
  end

  describe "write_file/3" do
    test "returns :ok by writing base64-decoded content inside the sandbox" do
      content = "hello world"
      expected_b64 = Base.encode64(content)

      MockCommandRunner
      |> expect(:run, fn "msb", ["exec", "sb-abc123", "--", "bash", "-c", command], _opts ->
        assert String.contains?(command, expected_b64)
        assert String.contains?(command, "/app/hello.txt")
        {"", 0}
      end)

      assert :ok =
               Microsandbox.write_file("sb-abc123", "/app/hello.txt", content, microsandbox())
    end

    test "returns error on failure" do
      MockCommandRunner
      |> expect(:run, fn "msb", _args, _opts ->
        {"Error: permission denied\n", 1}
      end)

      assert {:error, {:cmd_failed, 1, _}} =
               Microsandbox.write_file("sb-abc123", "/etc/passwd", "nope", microsandbox())
    end
  end
end
