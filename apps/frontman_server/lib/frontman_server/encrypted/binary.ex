defmodule FrontmanServer.Encrypted.Binary do
  @moduledoc """
  Encrypted binary field type for Ecto schemas.
  Uses the FrontmanServer.Vault for encryption/decryption.
  """

  use Cloak.Ecto.Binary, vault: FrontmanServer.Vault
end
