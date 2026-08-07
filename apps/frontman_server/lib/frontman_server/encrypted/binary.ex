# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Encrypted.Binary do
  @moduledoc """
  Encrypted binary field type for Ecto schemas.
  Uses the FrontmanServer.Vault for encryption/decryption.
  """

  use Cloak.Ecto.Binary, vault: FrontmanServer.Vault
end
