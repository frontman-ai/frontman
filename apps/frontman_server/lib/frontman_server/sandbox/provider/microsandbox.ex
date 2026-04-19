defmodule FrontmanServer.Sandbox.Provider.Microsandbox do
  @moduledoc """
  CLI wrapper for the `msb` (microsandbox) command.

  Translates Provider callbacks into `msb` CLI invocations via a
  `CommandRunner` behaviour. Stateless — each function call is an
  independent shell command. microsandbox manages VM lifecycle; this
  module is purely a client adapter.
  """

  @behaviour FrontmanServer.Sandbox.Provider

  alias FrontmanServer.Sandbox.CommandRunner

  @default_timeout_ms 30_000
  @create_timeout_ms 180_000

  # --- Provider callbacks ---

  @impl true
  def create(%FrontmanServer.Sandbox.EnvironmentSpec{} = spec, opts \\ []) do
    {caller_opts, create_opts} = extract_caller_opts(opts)

    port_forwards =
      Keyword.get(create_opts, :port_forwards, [])
      |> normalize_port_forwards()

    args =
      ["run", "--detach", "--name", spec.name] ++
        env_flags(spec.env) ++
        port_flags(port_forwards) ++
        [spec.image]

    case msb(args, caller_opts, timeout: @create_timeout_ms) do
      {:ok, _output} -> {:ok, spec.name}
      {:error, _} = error -> error
    end
  end

  @impl true
  def exec(ref, command, args, opts)
      when is_binary(ref) and is_binary(command) and is_list(args) do
    {caller_opts, exec_opts} = extract_caller_opts(opts)
    timeout = Keyword.get(exec_opts, :timeout_ms, @default_timeout_ms)

    msb_args = ["exec", ref, "--" | [command | args]]

    case msb(msb_args, caller_opts, timeout: timeout) do
      {:ok, output} ->
        {:ok, %{exit_code: 0, stdout: output, stderr: ""}}

      {:error, {:cmd_failed, code, output}} ->
        {:ok, %{exit_code: code, stdout: output, stderr: ""}}
    end
  end

  @impl true
  def metrics(ref, opts \\ []) when is_binary(ref) do
    with {:ok, output} <- msb(["list", "--format", "json"], opts, []),
         {:ok, entries} when is_list(entries) <- Jason.decode(output),
         entry when not is_nil(entry) <- Enum.find(entries, &(&1["name"] == ref)) do
      status = Map.get(entry, "status", "unknown")

      {:ok,
       %{
         running: status == "running",
         status: status,
         cpu_percent: Map.get(entry, "cpu_percent", 0.0),
         memory_bytes: Map.get(entry, "memory_bytes", 0)
       }}
    else
      nil -> {:error, :not_found}
      {:error, _} = error -> error
      _ -> {:error, :invalid_json}
    end
  end

  @impl true
  def stop(ref, opts \\ []) when is_binary(ref) do
    case msb(["stop", ref], opts, []) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def start(ref, opts \\ []) when is_binary(ref) do
    case msb(["start", ref], opts, []) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def destroy(ref, opts \\ []) when is_binary(ref) do
    # Stop first (tolerate "already stopped" errors), then remove.
    case msb(["stop", ref], opts, []) do
      {:ok, _} ->
        remove(ref, opts)

      {:error, {:cmd_failed, code, output}} ->
        if stopped_output?(output) do
          remove(ref, opts)
        else
          {:error, {:cmd_failed, code, output}}
        end
    end
  end

  defp remove(ref, opts) do
    case msb(["remove", ref], opts, []) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  defp stopped_output?(output) do
    String.contains?(output, "not running")
  end

  # --- Microsandbox-specific file operations (not Provider callbacks) ---

  @doc "Read a file from inside the sandbox VM via `cat`."
  @spec read_file(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def read_file(ref, path, opts \\ [])
      when is_binary(ref) and is_binary(path) do
    case exec(ref, "cat", [path], opts) do
      {:ok, %{exit_code: 0, stdout: content}} -> {:ok, content}
      {:ok, %{exit_code: code, stdout: output}} -> {:error, {:cmd_failed, code, output}}
    end
  end

  @doc """
  Write a file inside the sandbox VM via base64 decode.

  Content is base64-encoded and piped through `base64 -d` to avoid
  shell escaping issues.
  """
  @spec write_file(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def write_file(ref, path, content, opts \\ [])
      when is_binary(ref) and is_binary(path) and is_binary(content) do
    encoded = Base.encode64(content)

    case exec(
           ref,
           "bash",
           ["-c", ~S(printf '%s' "$1" | base64 -d > "$2"), "_", encoded, path],
           opts
         ) do
      {:ok, %{exit_code: 0}} -> :ok
      {:ok, %{exit_code: code, stdout: output}} -> {:error, {:cmd_failed, code, output}}
    end
  end

  # --- Internal ---

  defp msb(args, caller_opts, internal_opts) do
    timeout = Keyword.get(internal_opts, :timeout, @default_timeout_ms)
    runner = Keyword.get(caller_opts, :command_runner, default_runner())

    case runner.run("msb", args, stderr_to_stdout: true, timeout: timeout) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:cmd_failed, code, output}}
    end
  end

  defp extract_caller_opts(opts) do
    Keyword.split(opts, [:command_runner])
  end

  defp env_flags(env) when map_size(env) == 0, do: []

  defp env_flags(env) do
    Enum.flat_map(env, fn {k, v} -> ["--env", "#{k}=#{v}"] end)
  end

  defp normalize_port_forwards(port_forwards) do
    Enum.flat_map(port_forwards, fn
      %{host_port: host_port, guest_port: guest_port}
      when is_integer(host_port) and is_integer(guest_port) ->
        [%{host_port: host_port, guest_port: guest_port}]

      _ ->
        []
    end)
  end

  defp port_flags([]), do: []

  defp port_flags(port_forwards) do
    Enum.flat_map(port_forwards, fn %{host_port: host_port, guest_port: guest_port} ->
      ["--port", "#{host_port}:#{guest_port}"]
    end)
  end

  defp default_runner do
    Application.get_env(:frontman_server, :command_runner, CommandRunner.System)
  end
end
