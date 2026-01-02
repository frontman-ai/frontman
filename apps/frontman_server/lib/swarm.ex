defmodule Swarm do
  @moduledoc """
  Swarm is our agent execution framework.
  This is the public API
  """

  use TypedStruct

  alias Swarm.ExecutionProcess

  typedstruct module: ExecuteOpts do
    field :subscriber, pid() | nil, default: nil
    field :parent_id, String.t()
    field :max_steps, pos_integer(), default: 10
    field :timeout_ms, pos_integer(), default: 300_000
    field :step_timeout_ms, pos_integer(), default: 60_000
  end

  @doc """
  Starts an agent execution asynchronously.

  Returns immediately with an execution handle. Events are sent to the
  subscriber (defaults to calling process) as `{:swarm, execution_id, event}`
  messages.

  ## Example

      {:ok, execution} = Swarm.start(agent, "Hello")

      receive do
        {:swarm, _id, %Events.Started{}} -> IO.puts("Started!")
        {:swarm, _id, %Events.Completed{result: r}} -> IO.puts("Done: \#{r}")
      end
  """
  @spec start(Swarm.Agent.t(), String.t(), ExecuteOpts.t()) ::
          {:ok, Swarm.Execution.t()}
  def start(agent, message, opts \\ %ExecuteOpts{}) do
    subscriber = opts.subscriber || self()

    {:ok, %{pid: pid, execution_id: exec_id}} =
      ExecutionProcess.start_async(agent, message, opts, subscriber)

    {:ok, %Swarm.Execution{id: exec_id, pid: pid}}
  end

  @doc """
  Blocks until execution completes and returns the result.

  Consumes Started events while waiting for Completed or Failed.

  ## Options

    * `:timeout` - Max time to wait in ms (default: 300_000)

  ## Example

      {:ok, execution} = Swarm.start(agent, "Hello")
      {:ok, result} = Swarm.await(execution)
  """
  @spec await(Swarm.Execution.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def await(%Swarm.Execution{id: exec_id}, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 300_000)
    do_await(exec_id, timeout)
  end

  defp do_await(exec_id, timeout) do
    receive do
      {:swarm, ^exec_id, %Swarm.Events.Completed{result: result}} ->
        {:ok, result}

      {:swarm, ^exec_id, %Swarm.Events.Failed{error: error}} ->
        {:error, error}

      {:swarm, ^exec_id, _other} ->
        # Ignore Started and other events, keep waiting
        do_await(exec_id, timeout)
    after
      timeout -> {:error, :timeout}
    end
  end
end
