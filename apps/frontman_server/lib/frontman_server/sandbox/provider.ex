defmodule FrontmanServer.Sandbox.Provider do
  @moduledoc """
  Contract for sandbox infrastructure providers.

  A Provider is a stateless client adapter — each callback is an independent
  request to the underlying VM manager. No GenServer, no local process state.
  The provider ref is a string ID that the VM manager uses to identify the
  sandbox.

  Process management (supervision, heartbeat, state machine) lives in the
  Orchestrator (#834), not here.

  ## Runtime Resolution

  The Orchestrator resolves the provider implementation at runtime:

      provider = Application.get_env(:frontman_server, :sandbox_provider, Microsandbox)
      provider.create(env_spec)

  This allows swapping providers per environment (test mock, local CLI, future
  remote API) without changing Orchestrator code.
  """

  @type provider_ref :: String.t()

  @type exec_result :: %{
          exit_code: integer(),
          stdout: String.t(),
          stderr: String.t()
        }

  @type sandbox_metrics :: %{
          status: String.t(),
          cpu_percent: float(),
          memory_bytes: integer()
        }

  @type env_spec :: FrontmanServer.Sandbox.EnvironmentSpec.t()

  @doc """
  Create and start a VM from an environment spec.

  Returns the provider ref string used to identify this sandbox in all
  subsequent calls. The VM should be running and reachable when this returns.
  """
  @callback create(env_spec()) :: {:ok, provider_ref()} | {:error, term()}

  @doc """
  Execute a command inside the sandbox.

  Accepts `:timeout_ms` in opts — caller decides based on the command.
  """
  @callback exec(
              provider_ref(),
              command :: String.t(),
              args :: [String.t()],
              opts :: keyword()
            ) :: {:ok, exec_result()} | {:error, term()}

  @doc """
  Poll sandbox health and resource usage.

  Returns running status and resource metrics. Does NOT return vm_ip —
  the Orchestrator discovers that via `exec(ref, "hostname", ["-I"], [])`
  after creation.
  """
  @callback metrics(provider_ref()) :: {:ok, sandbox_metrics()} | {:error, term()}

  @doc "Stop the sandbox VM. Preserves filesystem and named volumes."
  @callback stop(provider_ref()) :: :ok | {:error, term()}

  @doc "Resume a previously stopped sandbox."
  @callback start(provider_ref()) :: :ok | {:error, term()}

  @doc "Destroy the sandbox and all its resources."
  @callback destroy(provider_ref()) :: :ok | {:error, term()}
end
