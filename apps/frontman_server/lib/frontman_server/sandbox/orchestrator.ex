defmodule FrontmanServer.Sandbox.Orchestrator do
  @moduledoc """
  Per-sandbox lifecycle GenServer.

  Manages a single sandbox VM through its lifecycle:
  provisioning → running → stopped/error. Polls the provider
  for health via heartbeat and delegates blocking exec calls
  to Task.Supervisor so the GenServer stays responsive.

  Started under Sandbox.DynamicSupervisor, registered in
  Sandbox.Registry by sandbox_id.
  """

  use GenServer, restart: :temporary

  require Logger

  alias FrontmanServer.Repo
  alias FrontmanServer.Sandbox.EnvironmentSpec
  alias FrontmanServer.Sandbox.SandboxSchema

  @default_heartbeat_interval_ms 30_000
  @default_provision_timeout_ms 300_000
  @default_exec_call_timeout_ms 120_000
  @exec_call_timeout_buffer_ms 5_000

  defstruct [
    :sandbox_id,
    :provider_ref,
    :status,
    :heartbeat_ref,
    :provision_timer_ref,
    :provider,
    :heartbeat_interval_ms,
    :provision_timeout_ms,
    :environment_spec,
    :task_supervisor
  ]

  # --- Client API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    sandbox_id = Keyword.fetch!(opts, :sandbox_id)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {FrontmanServer.Sandbox.Registry, sandbox_id}}
    )
  end

  @spec exec(String.t(), String.t(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def exec(sandbox_id, command, args, opts \\ []) do
    call_timeout = exec_call_timeout(opts)

    case safe_call(sandbox_id, {:exec, command, args, opts}, call_timeout) do
      {:ok, result} -> result
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec stop(String.t()) :: :ok | {:error, term()}
  def stop(sandbox_id) do
    case safe_call(sandbox_id, :stop) do
      {:ok, result} -> result
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec destroy(String.t()) :: :ok | {:error, term()}
  def destroy(sandbox_id) do
    case safe_call(sandbox_id, :destroy) do
      {:ok, result} -> result
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec status(String.t()) :: {:ok, atom()} | {:error, :not_found | :timeout | term()}
  def status(sandbox_id) do
    case safe_call(sandbox_id, :status) do
      {:ok, result} -> result
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp via(sandbox_id) do
    {:via, Registry, {FrontmanServer.Sandbox.Registry, sandbox_id}}
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    sandbox_id = Keyword.fetch!(opts, :sandbox_id)
    provider = Keyword.get(opts, :provider, default_provider())
    task_supervisor = Keyword.get(opts, :task_supervisor, FrontmanServer.Sandbox.TaskSupervisor)

    heartbeat_interval_ms =
      Keyword.get(opts, :heartbeat_interval_ms, @default_heartbeat_interval_ms)

    provision_timeout_ms =
      Keyword.get(opts, :provision_timeout_ms, @default_provision_timeout_ms)

    sandbox = Repo.get!(SandboxSchema, sandbox_id)

    state = %__MODULE__{
      sandbox_id: sandbox_id,
      provider: provider,
      status: :provisioning,
      heartbeat_interval_ms: heartbeat_interval_ms,
      provision_timeout_ms: provision_timeout_ms,
      task_supervisor: task_supervisor
    }

    case EnvironmentSpec.from_map(sandbox.env_spec) do
      {:ok, environment_spec} ->
        {:ok, %{state | environment_spec: environment_spec}, {:continue, :provision}}

      {:error, reason} ->
        Logger.error("[Orchestrator] invalid env_spec for #{sandbox_id}: #{inspect(reason)}")

        update_db_status(sandbox_id, :error)
        {:stop, :normal}
    end
  end

  @impl true
  def handle_continue(:provision, state) do
    case state.provider.create(state.environment_spec) do
      {:ok, provider_ref} ->
        sandbox = Repo.get!(SandboxSchema, state.sandbox_id)

        sandbox
        |> SandboxSchema.set_provider_ref_changeset(provider_ref)
        |> Repo.update!()

        provision_timer_ref =
          Process.send_after(self(), :provision_timeout, state.provision_timeout_ms)

        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)

        {:noreply,
         %{
           state
           | provider_ref: provider_ref,
             heartbeat_ref: heartbeat_ref,
             provision_timer_ref: provision_timer_ref
         }}

      {:error, reason} ->
        Logger.error(
          "[Orchestrator] provider.create failed for #{state.sandbox_id}: #{inspect(reason)}"
        )

        update_db_status(state.sandbox_id, :error)
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_call({:exec, command, args, opts}, from, %{status: :running} = state) do
    case start_exec_task(state.task_supervisor, fn ->
           result = state.provider.exec(state.provider_ref, command, args, opts)
           GenServer.reply(from, result)
         end) do
      {:ok, _pid} ->
        touch_last_active(state.sandbox_id)
        {:noreply, state}

      {:error, reason} ->
        {:reply, {:error, {:task_start_failed, reason}}, state}
    end
  end

  def handle_call({:exec, _, _, _}, _from, %{status: :provisioning} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call(:stop, _from, state) do
    case state.provider.stop(state.provider_ref) do
      :ok ->
        update_db_status(state.sandbox_id, :stopped)
        {:stop, :normal, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:destroy, _from, state) do
    case state.provider.destroy(state.provider_ref) do
      :ok ->
        case Repo.get(SandboxSchema, state.sandbox_id) do
          nil -> :ok
          sandbox -> Repo.delete(sandbox)
        end

        {:stop, :normal, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply, {:ok, state.status}, state}
  end

  @impl true
  def handle_info(:heartbeat, %{status: :provisioning} = state) do
    case state.provider.metrics(state.provider_ref) do
      {:ok, %{running: true}} ->
        if state.provision_timer_ref, do: Process.cancel_timer(state.provision_timer_ref)
        update_db_status(state.sandbox_id, :running)
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)

        {:noreply,
         %{state | status: :running, provision_timer_ref: nil, heartbeat_ref: heartbeat_ref}}

      {:ok, %{running: false}} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      _ ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
    end
  end

  def handle_info(:heartbeat, %{status: :running} = state) do
    case state.provider.metrics(state.provider_ref) do
      {:ok, %{running: true}} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:ok, %{running: false}} ->
        Logger.error("[Orchestrator] VM crashed for #{state.sandbox_id}")
        update_db_status(state.sandbox_id, :error)
        {:stop, :normal, state}

      {:error, _reason} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
    end
  end

  def handle_info(:provision_timeout, %{status: :provisioning} = state) do
    Logger.error("[Orchestrator] provisioning timed out for #{state.sandbox_id}")
    update_db_status(state.sandbox_id, :error)
    {:stop, :normal, state}
  end

  def handle_info(:provision_timeout, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    if state.heartbeat_ref, do: Process.cancel_timer(state.heartbeat_ref)
    if state.provision_timer_ref, do: Process.cancel_timer(state.provision_timer_ref)

    Logger.info(
      "[Orchestrator] terminating #{state.sandbox_id} (status=#{state.status}, reason=#{inspect(reason)})"
    )

    :ok
  end

  # --- Private Helpers ---

  defp schedule_heartbeat(interval_ms) do
    Process.send_after(self(), :heartbeat, interval_ms)
  end

  defp update_db_status(sandbox_id, new_status) do
    case Repo.get(SandboxSchema, sandbox_id) do
      nil ->
        Logger.warning("[Orchestrator] sandbox not found in DB: #{sandbox_id}")
        {:error, :not_found}

      sandbox ->
        sandbox
        |> SandboxSchema.status_changeset(new_status)
        |> Repo.update()
    end
  end

  defp touch_last_active(sandbox_id) do
    case Repo.get(SandboxSchema, sandbox_id) do
      nil ->
        :ok

      sandbox ->
        sandbox
        |> SandboxSchema.touch_changeset()
        |> Repo.update()
    end
  end

  defp default_provider do
    Application.get_env(
      :frontman_server,
      :sandbox_provider,
      FrontmanServer.Sandbox.Provider.Microsandbox
    )
  end

  defp exec_call_timeout(opts) do
    case Keyword.get(opts, :timeout_ms, @default_exec_call_timeout_ms) do
      :infinity ->
        :infinity

      timeout_ms when is_integer(timeout_ms) and timeout_ms > 0 ->
        timeout_ms + @exec_call_timeout_buffer_ms

      _ ->
        @default_exec_call_timeout_ms
    end
  end

  defp safe_call(sandbox_id, message, timeout \\ 5_000) do
    {:ok, GenServer.call(via(sandbox_id), message, timeout)}
  catch
    :exit, {:noproc, _} -> {:error, :not_found}
    :exit, :noproc -> {:error, :not_found}
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, {:normal, _} -> {:error, :server_terminated}
  end

  defp start_exec_task(task_supervisor, fun) do
    Task.Supervisor.start_child(task_supervisor, fun)
  catch
    :exit, reason -> {:error, reason}
  end
end
