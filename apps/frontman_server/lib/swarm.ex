defmodule Swarm do
  @moduledoc """
  Swarm is our agent execution framework.
  This is the public API
  """

  use TypedStruct

  alias Swarm.ExecutionProcess

  typedstruct module: ExecuteOpts do
    field :on_event, (Swarm.Events.event() -> :ok), default: &Swarm.noop/1
    field :parent_id, String.t()
    field :max_steps, pos_integer(), default: 10
    field :timeout_ms, pos_integer(), default: 300_000
    field :step_timeout_ms, pos_integer(), default: 60_000
  end

  @spec execute(Swarm.Agent.t(), String.t(), ExecuteOpts.t()) ::
          {:ok, String.t()} | {:error, term()}
  def execute(agent, message, opts \\ %ExecuteOpts{}) do
    ExecutionProcess.run(agent, message, opts)
  end

  def noop(_event), do: :ok
end
