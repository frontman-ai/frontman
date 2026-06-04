# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.SwarmDispatcher do
  @moduledoc """
  Bridges SwarmAi events into the Tasks context.

  Configured as the `event_dispatcher` MFA for `SwarmAi`.

  This module is intentionally only an adapter: task persistence and PubSub
  broadcasting are owned by `FrontmanServer.Tasks`.
  """

  alias FrontmanServer.Tasks

  @spec dispatch(term(), {atom(), term()}, map()) :: :ok | {:error, term()}
  def dispatch(key, event, context) do
    scope = Map.get(context, :scope)
    task_id = to_string(key)
    turn_number = Map.fetch!(context, :turn_number)

    Tasks.handle_swarm_event(scope, task_id, %{turn_number: turn_number, event: event})
  end
end
