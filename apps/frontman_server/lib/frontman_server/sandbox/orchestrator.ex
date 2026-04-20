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
    with {:ok, routing} <- build_port_routing(state.environment_spec),
         {:ok, provider_ref} <-
           state.provider.create(state.environment_spec, port_forwards: routing.port_forwards) do
      sandbox = Repo.get!(SandboxSchema, state.sandbox_id)

      sandbox
      |> Ecto.Changeset.change(
        provider_ref: provider_ref,
        port_map: routing.port_map,
        preview_url: preview_url(state.sandbox_id)
      )
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
    else
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

  defp build_port_routing(environment_spec) do
    guest_ports =
      environment_spec.devcontainer
      |> devcontainer_forward_ports()
      |> default_forward_ports()

    port_forwards =
      Enum.map(guest_ports, fn guest_port ->
        %{guest_port: guest_port, host_port: reserve_host_port()}
      end)

    case port_forwards do
      [%{host_port: preview_host_port} | _] ->
        port_map =
          Enum.reduce(port_forwards, %{}, fn %{guest_port: guest_port, host_port: host_port},
                                             acc ->
            Map.put(acc, Integer.to_string(guest_port), host_port)
          end)
          |> Map.put("web_preview_host_port", preview_host_port)

        {:ok, %{port_forwards: port_forwards, port_map: port_map}}

      [] ->
        {:error, :missing_forward_ports}
    end
  end

  defp devcontainer_forward_ports(devcontainer) when is_map(devcontainer) do
    forward_ports =
      Map.get_lazy(devcontainer, "forwardPorts", fn ->
        Map.get(devcontainer, :forwardPorts, [])
      end)

    case forward_ports do
      forward_ports when is_list(forward_ports) ->
        forward_ports
        |> Enum.flat_map(&normalize_forward_port/1)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  defp devcontainer_forward_ports(_), do: []

  defp normalize_forward_port(port) when is_integer(port) and port > 0 and port <= 65_535,
    do: [port]

  defp normalize_forward_port(port) when is_binary(port) do
    case Integer.parse(port) do
      {value, ""} when value > 0 and value <= 65_535 -> [value]
      _ -> []
    end
  end

  defp normalize_forward_port(_), do: []

  defp default_forward_ports([]), do: [3000]
  defp default_forward_ports(ports), do: ports

  defp reserve_host_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end

  defp preview_url(sandbox_id) do
    preview_config = Application.get_env(:frontman_server, :sandbox_preview_proxy, [])
    preview_base_host = Keyword.get(preview_config, :preview_base_host)

    case preview_base_host do
      base_host when is_binary(base_host) and byte_size(base_host) > 0 ->
        preview_scheme = Keyword.get(preview_config, :preview_scheme, "https")
        "#{preview_scheme}://#{sandbox_id}.#{base_host}"

      _ ->
        nil
    end
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
