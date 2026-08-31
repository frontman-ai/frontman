# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.EmbeddedClientAuth do
  @moduledoc """
  Shared session contract for embedded client authorization requests.
  """

  @pending_session_key :embedded_client_auth_request

  def pending_session_key, do: @pending_session_key
end
