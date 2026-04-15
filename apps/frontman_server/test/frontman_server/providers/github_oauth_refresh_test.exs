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
    scope = user_scope_fixture()
    %{scope: scope}
  end

  describe "refresh_oauth_token/2 for github" do
    test "returns existing access_token when refresh_token is empty (non-expiring token)",
         %{scope: scope} do
      # GitHub OAuth App tokens don't expire — "none" refresh_token signals this
      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "github",
          "gho_still_valid",
          "none",
          DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.truncate(:second)
        )

      token = Providers.get_oauth_token(scope, "github")
      assert {:ok, "gho_still_valid"} = Providers.refresh_oauth_token(scope, token)
    end

    test "returns error when refresh_token is present but refresh fails",
         %{scope: scope} do
      # GitHub App tokens expire and have refresh_tokens. Without real
      # GitHub App credentials configured, the refresh HTTP call will fail.
      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "github",
          "gho_expired",
          "ghr_refresh_token",
          DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.truncate(:second)
        )

      token = Providers.get_oauth_token(scope, "github")
      assert {:error, _} = Providers.refresh_oauth_token(scope, token)
    end
  end
end
