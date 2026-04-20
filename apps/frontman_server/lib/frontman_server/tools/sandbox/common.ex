# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Sandbox.Common do
  @moduledoc false

  alias FrontmanServer.Sandboxes
  alias FrontmanServer.Tools.Backend.Context

  @spec sandbox_from_context(Context.t()) ::
          {:ok, FrontmanServer.Sandboxes.Sandbox.t()} | {:error, String.t()}
  def sandbox_from_context(%Context{sandbox: nil}) do
    {:error, "Sandbox is not available for this task"}
  end

  def sandbox_from_context(%Context{sandbox: sandbox}), do: {:ok, sandbox}

  @spec project_root() :: String.t()
  def project_root do
    config = Application.get_env(:frontman_server, :sandbox_mvp, [])
    Keyword.get(config, :project_root, "/workspace/frontman")
  end

  @spec app_port() :: pos_integer()
  def app_port do
    config = Application.get_env(:frontman_server, :sandbox_mvp, [])
    Keyword.get(config, :app_port, 4000)
  end

  @spec health_path() :: String.t()
  def health_path do
    config = Application.get_env(:frontman_server, :sandbox_mvp, [])
    Keyword.get(config, :health_path, "/health/ready")
  end

  @spec resolve_relative_path(String.t()) ::
          {:ok, %{absolute: String.t(), relative: String.t()}} | {:error, String.t()}
  def resolve_relative_path(path) when is_binary(path) do
    trimmed = String.trim(path)

    cond do
      trimmed == "" ->
        {:error, "path is required"}

      String.starts_with?(trimmed, "/") ->
        resolve_absolute_path(trimmed)

      true ->
        pieces = String.split(trimmed, "/", trim: true)

        case Enum.any?(pieces, &(&1 == "..")) do
          true ->
            {:error, "path must not traverse parent directories"}

          false ->
            relative = Path.join(pieces)
            absolute = Path.join(project_root(), relative)
            {:ok, %{absolute: absolute, relative: relative}}
        end
    end
  end

  def resolve_relative_path(_), do: {:error, "path is required"}

  defp resolve_absolute_path(path) do
    root = project_root() |> Path.expand()
    absolute = Path.expand(path)

    cond do
      absolute == root ->
        {:ok, %{absolute: absolute, relative: "."}}

      String.starts_with?(absolute, root <> "/") ->
        {:ok, %{absolute: absolute, relative: Path.relative_to(absolute, root)}}

      true ->
        {:error, "path must be inside sandbox project root"}
    end
  end

  @spec run(Context.t(), String.t(), [String.t()], keyword()) ::
          {:ok, %{exit_code: integer(), stdout: String.t(), stderr: String.t()}}
          | {:error, String.t()}
  def run(%Context{} = context, command, args, opts \\ [])
      when is_binary(command) and is_list(args) do
    with {:ok, sandbox} <- sandbox_from_context(context),
         {:ok, result} <- Sandboxes.exec(context.scope, sandbox.id, command, args, opts) do
      {:ok, result}
    else
      {:error, reason} -> {:error, format_reason(reason)}
    end
  end

  @spec run_strict(Context.t(), String.t(), [String.t()], keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def run_strict(%Context{} = context, command, args, opts \\ [])
      when is_binary(command) and is_list(args) do
    case run(context, command, args, opts) do
      {:ok, %{exit_code: 0, stdout: stdout}} ->
        {:ok, stdout}

      {:ok, %{exit_code: exit_code, stdout: stdout, stderr: stderr}} ->
        {:error,
         "Sandbox command failed: command=#{command} exit_code=#{exit_code} stdout=#{String.trim(stdout)} stderr=#{String.trim(stderr)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec run_bash(Context.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def run_bash(%Context{} = context, script, opts \\ []) when is_binary(script) do
    run_strict(context, "bash", ["-lc", script], opts)
  end

  @spec run_bash_capture(Context.t(), String.t(), keyword()) ::
          {:ok, %{exit_code: integer(), stdout: String.t(), stderr: String.t()}}
          | {:error, String.t()}
  def run_bash_capture(%Context{} = context, script, opts \\ []) when is_binary(script) do
    run(context, "bash", ["-lc", script], opts)
  end

  @spec write_file(Context.t(), String.t(), String.t(), keyword()) :: :ok | {:error, String.t()}
  def write_file(%Context{} = context, absolute_path, content, opts \\ [])
      when is_binary(absolute_path) and is_binary(content) do
    encoded = Base.encode64(content)
    dir = Path.dirname(absolute_path)

    script =
      "mkdir -p " <>
        shell_escape(dir) <>
        " && printf '%s' " <>
        shell_escape(encoded) <>
        " | base64 -d > " <>
        shell_escape(absolute_path)

    case run_bash(context, script, opts) do
      {:ok, _stdout} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec shell_escape(String.t()) :: String.t()
  def shell_escape(value) when is_binary(value) do
    "'" <> String.replace(value, "'", "'\"'\"'") <> "'"
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
