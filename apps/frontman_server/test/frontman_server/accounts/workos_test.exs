# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Accounts.WorkOSTest do
  use FrontmanServer.DataCase, async: true

  alias FrontmanServer.Accounts.WorkOS

  describe "extract_oauth_tokens/1" do
    test "extracts GitHub oauth tokens from response body as a plain map" do
      body = %{
        "oauth_tokens" => %{
          "access_token" => "gho_abc123",
          "refresh_token" => "ghr_def456",
          "expires_at" => 1_700_000_000,
          "scopes" => ["repo"]
        }
      }

      assert %{
               access_token: "gho_abc123",
               refresh_token: "ghr_def456",
               expires_at: 1_700_000_000,
               scopes: ["repo"]
             } = WorkOS.extract_oauth_tokens(body)
    end

    test "returns nil when oauth_tokens is absent" do
      assert is_nil(WorkOS.extract_oauth_tokens(%{}))
    end

    test "returns nil when oauth_tokens is nil" do
      assert is_nil(WorkOS.extract_oauth_tokens(%{"oauth_tokens" => nil}))
    end

    test "passes through nil refresh_token as-is" do
      body = %{
        "oauth_tokens" => %{
          "access_token" => "gho_abc123",
          "refresh_token" => nil,
          "expires_at" => nil,
          "scopes" => ["repo"]
        }
      }

      tokens = WorkOS.extract_oauth_tokens(body)
      assert is_nil(tokens.refresh_token)
      assert is_nil(tokens.expires_at)
    end
  end
end
