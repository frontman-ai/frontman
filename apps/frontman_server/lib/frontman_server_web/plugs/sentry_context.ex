# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.SentryContext do
  @moduledoc false

  alias FrontmanServer.Observability.SentryContext

  def init(opts), do: opts

  def call(conn, _opts) do
    conn.assigns[:current_scope]
    |> SentryContext.set_scope_context()

    conn
  end
end
