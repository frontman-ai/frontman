# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.BillingHTML do
  @moduledoc """
  HTML pages for server-owned billing browser flows.
  """
  use FrontmanServerWeb, :html

  embed_templates "billing_html/*"
end
