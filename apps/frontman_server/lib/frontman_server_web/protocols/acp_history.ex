# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defprotocol FrontmanServerWeb.ACPHistory do
  @moduledoc """
  Protocol for converting domain types to ACP history format.

  History items are used for session hydration - the client replays them
  through its existing session update handler to reconstruct state.
  """

  @doc """
  Converts an interaction to a list of history items.

  Returns a list because some interactions (like AgentResponse) expand
  to multiple history items (start, chunk, end).
  """
  def to_history_items(interaction, session_id)
end
