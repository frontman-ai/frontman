defmodule FrontmanServer.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: FrontmanServer.Vault
end
