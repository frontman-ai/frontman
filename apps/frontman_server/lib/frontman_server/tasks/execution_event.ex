defmodule FrontmanServer.Tasks.ExecutionEvent do
  @moduledoc """
  Domain event emitted during task execution.

  Wraps raw SwarmAi runtime events with causation context — which user
  interaction triggered this execution. The SwarmDispatcher acts as an
  Anti-Corruption Layer, translating infrastructure events into these
  domain events before broadcasting on PubSub.
  """

  @type interaction_id :: String.t()

  @type event_type ::
          :chunk
          | :response
          | :tool_call
          | :completed
          | :failed
          | :crashed
          | :cancelled
          | :terminated
          | :paused

  @enforce_keys [:type]
  defstruct [:type, :payload, :caused_by]

  @type t :: %__MODULE__{
          type: event_type(),
          payload: term(),
          caused_by: interaction_id() | nil
        }
end
