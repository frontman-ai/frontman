# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Accounts.WorkOSTest do
  use FrontmanServer.DataCase, async: true

  alias FrontmanServer.Accounts.WorkOS

  describe "extract_oauth_tokens/1" do
    test "extracts GitHub oauth tokens from response body" do
      body = %{
        "oauth_tokens" => %{
          "access_token" => "gho_abc123",
          "refresh_token" => "ghr_def456",
          "expires_at" => 1_700_000_000,
          "scopes" => ["repo"]
        }
      }

      assert {:ok, tokens} = WorkOS.extract_oauth_tokens(body)
      assert tokens.access_token == "gho_abc123"
      assert tokens.refresh_token == "ghr_def456"
      assert tokens.expires_at == 1_700_000_000
      assert tokens.scopes == ["repo"]
    end

    test "returns :none when oauth_tokens is absent" do
      assert :none = WorkOS.extract_oauth_tokens(%{})
    end

    test "returns :none when oauth_tokens is nil" do
      assert :none = WorkOS.extract_oauth_tokens(%{"oauth_tokens" => nil})
    end
  end
end
