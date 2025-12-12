defmodule FrontmanServer.Agents.SubAgent do
  @moduledoc """
  Tracks a spawned sub-agent for observability.

  A sub-agent is just an agent with a parent_pid - this struct tracks its lifecycle.
  """

  alias FrontmanServer.Agents

  @type status :: :running | :completed | :failed

  @enforce_keys [:id, :tool_call_id, :role, :message, :pid, :status, :started_at]
  defstruct [:id, :tool_call_id, :role, :message, :pid, :status, :started_at, :result, :error]

  @type t :: %__MODULE__{
          id: String.t(),
          tool_call_id: String.t(),
          role: Agents.role(),
          message: String.t(),
          pid: pid(),
          status: status(),
          started_at: integer(),
          result: String.t() | nil,
          error: term() | nil
        }
end
