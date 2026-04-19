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

  describe "create/2" do
    test "returns {:ok, name} when msb run succeeds" do
      env_spec = valid_env_spec()

      MockCommandRunner
      |> expect(:run, fn "msb", args, _opts ->
        assert "run" in args
        assert "--detach" in args
        assert "--name" in args
        assert "test-sandbox" in args
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

    test "passes configured port forwards" do
      env_spec = valid_env_spec()
      host_port = 13_000

      MockCommandRunner
      |> expect(:run, fn "msb", args, _opts ->
        assert args
               |> Enum.chunk_every(2, 1, :discard)
               |> Enum.any?(fn
                 ["--port", value] -> value == "#{host_port}:3000"
                 _ -> false
               end)

        {"Sandbox test-sandbox is running\n", 0}
      end)

      assert {:ok, "test-sandbox"} =
               Microsandbox.create(
                 env_spec,
                 microsandbox(port_forwards: [%{host_port: host_port, guest_port: 3000}])
               )
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

    test "returns {:ok, exec_result} with non-zero exit code when command fails inside sandbox" do
      MockCommandRunner
      |> expect(:run, fn "msb", _args, _opts ->
        {"test failed\n", 1}
      end)

      assert {:ok, %{exit_code: 1, stdout: "test failed\n", stderr: ""}} =
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

    test "returns non-zero exit code from inner command as {:ok, exec_result}" do
      MockCommandRunner
      |> expect(:run, fn "msb", _args, _opts ->
        {"Error: sandbox not found\n", 1}
      end)

      assert {:ok, %{exit_code: 1, stdout: "Error: sandbox not found\n", stderr: ""}} =
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
      |> expect(:run, fn "msb", ["list", "--format", "json"], _opts ->
        {json_output, 0}
      end)

      assert {:ok, metrics} = Microsandbox.metrics("sb-abc123", microsandbox())
      assert metrics.running
      assert metrics.status == "running"
      assert metrics.cpu_percent == 12.5
      assert metrics.memory_bytes == 268_435_456
    end

    test "returns error when sandbox not found in list" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["list", "--format", "json"], _opts ->
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

    test "returns stop error when stop fails unexpectedly" do
      MockCommandRunner
      |> expect(:run, fn "msb", ["stop", "sb-abc123"], _opts ->
        {"Error: daemon unreachable\n", 1}
      end)

      assert {:error, {:cmd_failed, 1, "Error: daemon unreachable\n"}} =
               Microsandbox.destroy("sb-abc123", microsandbox())
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
      |> expect(:run, fn "msb",
                         ["exec", "sb-abc123", "--", "bash", "-c", _cmd, "_", encoded, path_arg],
                         _opts ->
        assert encoded == expected_b64
        assert path_arg == "/app/hello.txt"
        {"", 0}
      end)

      assert :ok =
               Microsandbox.write_file("sb-abc123", "/app/hello.txt", content, microsandbox())
    end

    test "path is passed as positional arg, never interpolated in shell command" do
      malicious_path = "/tmp/foo; rm -rf /"
      content = "safe"

      MockCommandRunner
      |> expect(:run, fn "msb",
                         [
                           "exec",
                           "sb-abc123",
                           "--",
                           "bash",
                           "-c",
                           command,
                           "_",
                           _encoded,
                           path_arg
                         ],
                         _opts ->
        # Shell template must NOT contain the path
        refute String.contains?(command, malicious_path)
        # Path arrives as a separate argv element
        assert path_arg == malicious_path
        {"", 0}
      end)

      assert :ok =
               Microsandbox.write_file("sb-abc123", malicious_path, content, microsandbox())
    end

    test "shell metacharacters in path cannot be interpreted" do
      paths = [
        "/tmp/$(whoami)/file",
        "/tmp/`id`/file",
        "/tmp/foo | cat /etc/shadow",
        "/tmp/foo\nrm -rf /"
      ]

      for path <- paths do
        MockCommandRunner
        |> expect(:run, fn "msb",
                           ["exec", _ref, "--", "bash", "-c", cmd, "_", _encoded, path_arg],
                           _opts ->
          refute String.contains?(cmd, path)
          assert path_arg == path
          {"", 0}
        end)

        assert :ok =
                 Microsandbox.write_file("sb-abc123", path, "x", microsandbox())
      end
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
