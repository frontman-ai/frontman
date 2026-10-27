defmodule FrontmanServer.Protocols.MCP.RetryPolicy do
  @moduledoc """
  Pure admission policy for a future MRTR coordinator, not dispatch authorization.
  Caller supplies budgets; attempts include the initial request, elapsed time is monotonic.
  Permission must come from trusted operation policy, never remote tool hints.
  Tasks must atomically check cancellation, attempt fencing and terminal resolution.
  Opaque state, arguments and tool output deliberately never enter this policy.
  """

  @type observation ::
          :acknowledged_interim
          | :cancelled
          | :outcome_unknown
          | :unsupported_input
          | :protocol_failure
  @type permission :: :authorized | :denied
  @type decision ::
          :request_continuation
          | {:stop,
             :cancelled
             | :outcome_unknown
             | :unsupported_input
             | :protocol_failure
             | :retry_not_permitted
             | :retry_exhausted}

  @spec decide(
          observation(),
          permission(),
          pos_integer(),
          pos_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: decision()
  def decide(observation, permission, attempts, attempts_max, elapsed_ms, elapsed_ms_max)
      when observation in [
             :acknowledged_interim,
             :cancelled,
             :outcome_unknown,
             :unsupported_input,
             :protocol_failure
           ] and permission in [:authorized, :denied] and
             is_integer(attempts) and attempts > 0 and
             is_integer(attempts_max) and attempts_max > 0 and
             is_integer(elapsed_ms) and elapsed_ms >= 0 and
             is_integer(elapsed_ms_max) and elapsed_ms_max > 0 do
    case {observation, permission} do
      {:acknowledged_interim, :denied} ->
        {:stop, :retry_not_permitted}

      {:acknowledged_interim, :authorized} ->
        cond do
          attempts >= attempts_max -> {:stop, :retry_exhausted}
          elapsed_ms >= elapsed_ms_max -> {:stop, :retry_exhausted}
          true -> :request_continuation
        end

      {reason, _permission} ->
        {:stop, reason}
    end
  end
end
