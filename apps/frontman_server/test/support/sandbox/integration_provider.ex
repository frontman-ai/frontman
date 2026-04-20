defmodule FrontmanServer.Test.Support.Sandbox.IntegrationProvider do
  @moduledoc false

  @behaviour FrontmanServer.Sandbox.Provider

  alias FrontmanServer.Sandbox.EnvironmentSpec

  @table __MODULE__

  @spec reset!() :: :ok
  def reset! do
    table = ensure_table()
    :ets.delete_all_objects(table)
    :ok
  end

  @spec ref_for_name(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def ref_for_name(name) when is_binary(name) do
    table = ensure_table()

    case :ets.lookup(table, {:name_ref, name}) do
      [{{:name_ref, ^name}, ref}] -> {:ok, ref}
      [] -> {:error, :not_found}
    end
  end

  @spec set_running(String.t(), boolean()) :: :ok | {:error, :not_found}
  def set_running(ref, running) when is_binary(ref) and is_boolean(running) do
    update_state(ref, fn state -> %{state | running: running} end)
  end

  @spec set_metrics_error(String.t(), term() | nil) :: :ok | {:error, :not_found}
  def set_metrics_error(ref, reason) when is_binary(ref) do
    update_state(ref, fn state -> %{state | metrics_error: reason} end)
  end

  @impl true
  def create(%EnvironmentSpec{} = spec, _opts \\ []) do
    table = ensure_table()

    maybe_delay(spec)

    if create_error?(spec) do
      {:error, :create_failed}
    else
      ref = "integration-#{spec.name}-#{System.unique_integer([:positive])}"

      state = %{
        running: bool_env(spec, "initial_running", true),
        metrics_error: nil,
        exec_exit_code: int_env(spec, "exec_exit_code", 0),
        exec_stdout: Map.get(spec.env, "exec_stdout", "ok\n")
      }

      true = :ets.insert(table, {{:state, ref}, state})
      true = :ets.insert(table, {{:name_ref, spec.name}, ref})
      {:ok, ref}
    end
  end

  @impl true
  def exec(ref, _command, _args, _opts) when is_binary(ref) do
    case fetch_state(ref) do
      {:ok, state} ->
        {:ok,
         %{
           exit_code: state.exec_exit_code,
           stdout: state.exec_stdout,
           stderr: ""
         }}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @impl true
  def metrics(ref) when is_binary(ref) do
    case fetch_state(ref) do
      {:ok, %{metrics_error: nil} = state} ->
        {:ok, %{running: state.running}}

      {:ok, %{metrics_error: reason}} ->
        {:error, reason}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @impl true
  def stop(ref) when is_binary(ref) do
    set_running(ref, false)
  end

  @impl true
  def start(ref) when is_binary(ref) do
    set_running(ref, true)
  end

  @impl true
  def destroy(ref) when is_binary(ref) do
    table = ensure_table()

    case :ets.lookup(table, {:state, ref}) do
      [] ->
        {:error, :not_found}

      [_] ->
        true = :ets.delete(table, {:state, ref})
        :ok
    end
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      table -> table
    end
  end

  defp fetch_state(ref) do
    table = ensure_table()

    case :ets.lookup(table, {:state, ref}) do
      [{{:state, ^ref}, state}] -> {:ok, state}
      [] -> {:error, :not_found}
    end
  end

  defp update_state(ref, update_fun) do
    table = ensure_table()

    case :ets.lookup(table, {:state, ref}) do
      [{{:state, ^ref}, state}] ->
        true = :ets.insert(table, {{:state, ref}, update_fun.(state)})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  defp maybe_delay(spec) do
    delay_ms = int_env(spec, "create_delay_ms", 0)

    if delay_ms > 0 do
      Process.sleep(delay_ms)
    end
  end

  defp create_error?(spec) do
    bool_env(spec, "create_error", false)
  end

  defp bool_env(spec, key, default) do
    case Map.get(spec.env, key) do
      "true" -> true
      "false" -> false
      nil -> default
      _ -> default
    end
  end

  defp int_env(spec, key, default) do
    case Integer.parse(Map.get(spec.env, key, "")) do
      {value, ""} -> value
      _ -> default
    end
  end
end
