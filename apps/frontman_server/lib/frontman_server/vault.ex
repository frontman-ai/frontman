# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Vault do
  @moduledoc """
  Vault module for encrypting sensitive data at rest using Cloak.

  Configuration requires setting the cloak_key in runtime config.
  Generate a key with: `:crypto.strong_rand_bytes(32) |> Base.encode64()`
  """

  use Cloak.Vault, otp_app: :frontman_server

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: get_key!(), iv_length: 12
        }
      )

    {:ok, config}
  end

  defp get_key! do
    case Application.get_env(:frontman_server, :cloak_key) do
      nil ->
        raise """
        Config :frontman_server, :cloak_key is not set.

        Generate a key with:
          :crypto.strong_rand_bytes(32) |> Base.encode64()

        Then set CLOAK_KEY in your env file.
        """

      value ->
        Base.decode64!(value)
    end
  end
end
