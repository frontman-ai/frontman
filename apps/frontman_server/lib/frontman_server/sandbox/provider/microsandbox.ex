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
    args =
      ["run", "--name", spec.name, "--image", spec.image] ++
        env_flags(spec.env) ++
        devcontainer_flags(spec.devcontainer)

    case msb(args, opts, timeout: @create_timeout_ms) do
      {:ok, _output} -> {:ok, spec.name}
      {:error, _} = error -> error
    end
  end

  @impl true
  def exec(_ref, _command, _args, _opts), do: {:error, :not_implemented}

  @impl true
  def metrics(_ref), do: {:error, :not_implemented}

  @impl true
  def stop(_ref), do: {:error, :not_implemented}

  @impl true
  def start(_ref), do: {:error, :not_implemented}

  @impl true
  def destroy(_ref), do: {:error, :not_implemented}

  # --- Internal ---

  defp msb(args, caller_opts, internal_opts) do
    timeout = Keyword.get(internal_opts, :timeout, @default_timeout_ms)
    runner = Keyword.get(caller_opts, :command_runner, default_runner())

    case runner.run("msb", args, stderr_to_stdout: true, timeout: timeout) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:cmd_failed, code, output}}
    end
  end

  defp env_flags(env) when map_size(env) == 0, do: []

  defp env_flags(env) do
    Enum.flat_map(env, fn {k, v} -> ["--env", "#{k}=#{v}"] end)
  end

  defp devcontainer_flags(dc) when map_size(dc) == 0, do: []

  defp devcontainer_flags(dc) do
    path =
      Path.join(
        System.tmp_dir!(),
        "msb-devcontainer-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, Jason.encode!(dc))
    ["--config", path]
  end

  defp default_runner do
    Application.get_env(:frontman_server, :command_runner, CommandRunner.System)
  end
end
