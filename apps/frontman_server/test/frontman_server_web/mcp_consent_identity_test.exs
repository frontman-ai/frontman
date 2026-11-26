defmodule FrontmanServerWeb.MCP.ConsentIdentityTest do
  use ExUnit.Case, async: true

  alias FrontmanServerWeb.MCP.ConsentIdentity

  # These pure checks cover identity boundaries without creating OAuth grants.
  test "consent correlation is stable across token refresh, but not across users or clients" do
    auth = %{
      sub: Ecto.UUID.generate(),
      client_id: "https://assistant.example/client.json",
      raw_claims: %{"sid" => "consent-one", "jti" => "token-one"}
    }

    assert %{mcp_connection_id: id} = ConsentIdentity.properties(auth)
    assert byte_size(id) == 43
    refute String.contains?(id, "consent-one")

    refreshed = %{auth | raw_claims: %{"sid" => "consent-one", "jti" => "token-two"}}
    assert ConsentIdentity.properties(refreshed) == %{mcp_connection_id: id}

    for different <- [
          %{auth | sub: Ecto.UUID.generate()},
          %{auth | client_id: "https://another.example/client.json"},
          %{auth | raw_claims: %{"sid" => "consent-two"}}
        ] do
      refute ConsentIdentity.properties(different) == %{mcp_connection_id: id}
    end
  end

  test "missing or malformed verified consent context remains uncorrelated" do
    for auth <- [
          nil,
          %{},
          %{sub: Ecto.UUID.generate(), client_id: "client", raw_claims: %{}},
          %{sub: "invalid", client_id: "client", raw_claims: %{"sid" => "consent"}},
          %{sub: Ecto.UUID.generate(), client_id: "", raw_claims: %{"sid" => "consent"}},
          %{sub: Ecto.UUID.generate(), client_id: "client", raw_claims: %{"sid" => ""}},
          %{
            sub: Ecto.UUID.generate(),
            client_id: "client",
            raw_claims: %{"sid" => String.duplicate("a", 513)}
          }
        ] do
      assert ConsentIdentity.properties(auth) == %{}
    end
  end
end
