# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.OAuthTokenStorageTest do
  use FrontmanServer.DataCase, async: true

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  import FrontmanServer.Test.Fixtures.Accounts

  setup do
    %{user: user_fixture()}
  end

  describe "GitHub OAuth token storage via Providers" do
    test "stores and retrieves GitHub OAuth token", %{user: user} do
      scope = Scope.for_user(user)

      expires_at =
        DateTime.utc_now()
        |> DateTime.add(28_800, :second)
        |> DateTime.truncate(:second)

      assert {:ok, _token} =
               Providers.save_oauth_connection(
                 scope,
                 "github",
                 "gho_test_token",
                 "ghr_test_refresh",
                 expires_at,
                 %{"scopes" => ["repo"]}
               )

      assert {:ok, "gho_test_token"} =
               Providers.get_valid_oauth_token(scope, "github")
    end

    test "stores token with nil refresh_token and nil expires_at", %{user: user} do
      scope = Scope.for_user(user)

      assert {:ok, _token} =
               Providers.save_oauth_connection(
                 scope,
                 "github",
                 "gho_non_expiring",
                 nil,
                 nil,
                 %{"scopes" => ["repo"]}
               )

      assert {:ok, "gho_non_expiring"} =
               Providers.get_valid_oauth_token(scope, "github")
    end
  end
end
