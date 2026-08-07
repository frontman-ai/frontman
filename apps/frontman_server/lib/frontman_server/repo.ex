# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Repo do
  use Ecto.Repo,
    otp_app: :frontman_server,
    adapter: Ecto.Adapters.Postgres
end
