# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.GitHubOAuthRefreshTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Providers

  setup do
    Application.put_env(:frontman_server, :github_oauth_req_options,
      plug: {Req.Test, :github_oauth}
    )

    Application.put_env(:frontman_server, :github_oauth,
      client_id: "test_client_id",
      client_secret: "test_client_secret"
    )

    on_exit(fn ->
      Application.delete_env(:frontman_server, :github_oauth_req_options)
    end)

    scope = user_scope_fixture()
    %{scope: scope}
  end

  defp expired_datetime do
    DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.truncate(:second)
  end

  describe "refresh_oauth_token/2 for github" do
    test "returns existing access_token when refresh_token is nil (non-expiring)",
         %{scope: scope} do
      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "github",
          "gho_still_valid",
          nil,
          nil
        )

      token = Providers.get_oauth_token(scope, "github")
      assert {:ok, "gho_still_valid"} = Providers.refresh_oauth_token(scope, token)
    end

    test "refreshes token successfully when GitHub returns new tokens",
         %{scope: scope} do
      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "github",
          "gho_expired",
          "ghr_real_refresh",
          expired_datetime()
        )

      Req.Test.stub(:github_oauth, fn conn ->
        Req.Test.json(conn, %{
          "access_token" => "gho_refreshed",
          "refresh_token" => "ghr_new_refresh",
          "expires_in" => 3600
        })
      end)

      token = Providers.get_oauth_token(scope, "github")
      assert {:ok, "gho_refreshed"} = Providers.refresh_oauth_token(scope, token)
    end

    test "returns error when GitHub refresh endpoint returns an error",
         %{scope: scope} do
      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "github",
          "gho_expired",
          "ghr_bad",
          expired_datetime()
        )

      Req.Test.stub(:github_oauth, fn conn ->
        Req.Test.json(conn, %{"error" => "bad_refresh_token"})
      end)

      token = Providers.get_oauth_token(scope, "github")

      assert {:error, {:refresh_failed, {:github_error, "bad_refresh_token"}}} =
               Providers.refresh_oauth_token(scope, token)
    end
  end
end
