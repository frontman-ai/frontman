defmodule FrontmanServerWeb.MCP.ConsentIdentity do
  @moduledoc """
  Correlates authenticated MCP requests by WorkOS consent, not browser attempt.

  Only call with the authorization context after the MCP authorization layer
  validates the token. Raw bearer tokens and rejected claims are not inputs.
  """

  def properties(%{
        sub: subject,
        client_id: client_id,
        raw_claims: %{"sid" => consent_id}
      })
      when is_binary(client_id) and byte_size(client_id) in 1..1024 and
             is_binary(consent_id) and byte_size(consent_id) in 1..512 do
    case Ecto.UUID.cast(subject) do
      {:ok, user_id} ->
        # JSON preserves tuple boundaries; raw registration and consent IDs stay private.
        encoded = JSON.encode!(["mcp-consent-v1", user_id, client_id, consent_id])
        id = :sha256 |> :crypto.hash(encoded) |> Base.url_encode64(padding: false)
        %{mcp_connection_id: id}

      :error ->
        %{}
    end
  end

  def properties(_auth), do: %{}
end
