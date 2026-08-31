# Frontman Server
# Copyright (C) 2025 Frontman AI
# Licensed under the AGPL-3.0 — see LICENSE for details.

defmodule FrontmanServerWeb.CustomProvidersControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    conn = put_embedded_client_bearer(conn, user)

    %{conn: conn, user: user}
  end

  test "creates and lists sanitized aggregates", %{conn: conn} do
    secret = "sk-custom-secret-value"
    conn = create_provider(conn, %{"api_key" => secret})

    assert %{"data" => provider} = json_response(conn, 201)
    assert provider["lock_version"] == 1
    assert provider["has_api_key"]
    refute Map.has_key?(provider, "api_key")
    refute conn.resp_body =~ secret

    conn = get(conn, ~p"/api/user/custom-providers")
    assert %{"data" => [listed]} = json_response(conn, 200)
    assert listed == provider
    refute conn.resp_body =~ secret
  end

  test "requires bearer authentication", %{user: user} do
    conn =
      build_conn()
      |> post(~p"/api/user/custom-providers", %{
        "name" => "vLLM",
        "base_url" => "http://93.184.216.34:8000/v1"
      })

    assert json_response(conn, 401)["error"] == "authentication_required"

    conn =
      build_conn()
      |> log_in_user(user)
      |> post(~p"/api/user/custom-providers", %{
        "name" => "vLLM",
        "base_url" => "http://93.184.216.34:8000/v1"
      })

    assert json_response(conn, 401)["error"] == "authentication_required"
  end

  test "malformed provider IDs return not found", %{conn: conn} do
    conn = create_provider(conn)
    %{"data" => provider} = json_response(conn, 201)

    conn = put(conn, ~p"/api/user/custom-providers/not-a-uuid", replacement(provider))
    assert %{"code" => "not_found"} = json_response(conn, 404)
  end

  test "returns latest sanitized aggregate for stale update and delete", %{conn: conn} do
    conn = create_provider(conn, %{"api_key" => "secret"})
    %{"data" => original} = json_response(conn, 201)

    conn =
      put(
        conn,
        ~p"/api/user/custom-providers/#{original["id"]}",
        replacement(original, %{"name" => "winner"})
      )

    %{"data" => current} = json_response(conn, 200)

    conn =
      put(
        conn,
        ~p"/api/user/custom-providers/#{original["id"]}",
        replacement(original, %{"name" => "loser"})
      )

    assert %{"code" => "stale", "current_provider" => conflict} = json_response(conn, 409)
    assert conflict == current

    conn =
      delete(
        conn,
        ~p"/api/user/custom-providers/#{original["id"]}?lock_version=#{original["lock_version"]}"
      )

    assert %{"code" => "stale", "current_provider" => ^current} = json_response(conn, 409)
  end

  test "validates replacement and delete contracts", %{conn: conn} do
    conn = create_provider(conn)
    %{"data" => provider} = json_response(conn, 201)
    refute provider["has_api_key"]

    conn = create_provider(conn, %{"name" => "empty-key", "api_key" => ""})
    refute json_response(conn, 201)["data"]["has_api_key"]

    conn = put(conn, ~p"/api/user/custom-providers/#{provider["id"]}", %{"name" => "partial"})
    assert %{"code" => "validation_failed", "errors" => errors} = json_response(conn, 422)
    assert errors["models"] == ["is required"]

    conn = delete(conn, ~p"/api/user/custom-providers/#{provider["id"]}?lock_version=0")
    assert %{"code" => "validation_failed"} = json_response(conn, 422)

    conn =
      delete(
        conn,
        ~p"/api/user/custom-providers/#{provider["id"]}?lock_version=#{provider["lock_version"]}"
      )

    assert response(conn, 204) == ""
  end

  defp create_provider(conn, attrs \\ %{}) do
    post(
      conn,
      ~p"/api/user/custom-providers",
      Map.merge(
        %{"name" => "vLLM", "base_url" => "http://93.184.216.34:8000/v1", "models" => []},
        attrs
      )
    )
  end

  defp replacement(provider, attrs \\ %{}) do
    Map.merge(
      %{
        "name" => provider["name"],
        "base_url" => provider["base_url"],
        "models" => provider["models"],
        "lock_version" => provider["lock_version"],
        "api_key_change" => %{"action" => "keep"}
      },
      attrs
    )
  end
end
