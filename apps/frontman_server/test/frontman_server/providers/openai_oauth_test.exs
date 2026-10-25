defmodule FrontmanServer.Providers.OpenAIOAuthTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.OpenAIOAuth

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  describe "available_model_ids/2" do
    test "uses account-scoped Codex discovery and preserves subscription-only models" do
      Req.Test.expect(:openai_oauth, fn conn ->
        assert conn.method == "GET"
        assert conn.host == "chatgpt.com"
        assert conn.request_path == "/backend-api/codex/models"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-access"]
        assert Plug.Conn.get_req_header(conn, "chatgpt-account-id") == ["test-account"]
        assert Plug.Conn.get_req_header(conn, "originator") == ["pi"]
        assert Plug.Conn.fetch_query_params(conn).query_params == %{"client_version" => "0.164.0"}

        Req.Test.json(conn, %{
          "models" => [
            %{
              "slug" => "subscription-model",
              "visibility" => "list",
              "supported_in_api" => false
            },
            %{"slug" => "hidden-model", "visibility" => "hide"},
            %{"slug" => "unavailable-model", "visibility" => "none"}
          ]
        })
      end)

      assert {:ok, ids} = OpenAIOAuth.available_model_ids("test-access", "test-account")
      assert ids == MapSet.new(["subscription-model"])
    end

    test "rejects malformed catalogs instead of treating them as availability" do
      for body <- [
            %{},
            %{"models" => nil},
            %{"models" => [%{"slug" => "gpt-test"}]},
            %{"models" => [%{"slug" => "", "visibility" => "list"}]},
            %{"models" => [%{"slug" => "gpt-test", "visibility" => "unknown"}]},
            %{"models" => [%{"slug" => "valid", "visibility" => "list"}, nil]}
          ] do
        Req.Test.expect(:openai_oauth, &Req.Test.json(&1, body))

        assert {:error, :model_discovery_failed} =
                 OpenAIOAuth.available_model_ids("test-access", "test-account")
      end
    end

    test "does not retry, follow redirects, or expose provider data on failure" do
      for status <- [302, 401, 403, 429, 500] do
        Req.Test.expect(:openai_oauth, fn conn ->
          conn
          |> Plug.Conn.put_resp_header("location", "https://untrusted.example/models")
          |> Plug.Conn.put_status(status)
          |> Req.Test.json(%{"message" => "private-input"})
        end)

        expected =
          if status in [401, 403], do: :invalid_oauth_token, else: :model_discovery_failed

        log =
          ExUnit.CaptureLog.capture_log(fn ->
            assert {:error, ^expected} =
                     OpenAIOAuth.available_model_ids("test-access", "test-account")
          end)

        refute log =~ "test-access"
        refute log =~ "test-account"
        refute log =~ "private-input"
      end
    end

    test "transport errors fail closed" do
      Req.Test.expect(:openai_oauth, &Req.Test.transport_error(&1, :timeout))

      assert {:error, :model_discovery_failed} =
               OpenAIOAuth.available_model_ids("test-access", "test-account")
    end

    test "missing account identity never sends credentials" do
      assert {:error, :invalid_oauth_token} = OpenAIOAuth.available_model_ids("test-access", nil)
      assert {:error, :invalid_oauth_token} = OpenAIOAuth.available_model_ids("test-access", "")
    end
  end

  defp build_jwt(claims) do
    header = Base.url_encode64(Jason.encode!(%{"alg" => "RS256"}), padding: false)
    payload = Base.url_encode64(Jason.encode!(claims), padding: false)
    signature = Base.url_encode64("fake_signature", padding: false)
    "#{header}.#{payload}.#{signature}"
  end

  describe "extract_account_id_from_tokens/1" do
    test "extracts account_id from OpenAI auth claim" do
      jwt =
        build_jwt(%{"https://api.openai.com/auth" => %{"chatgpt_account_id" => "acct_123"}})

      assert "acct_123" = OpenAIOAuth.extract_account_id_from_tokens(%{id_token: jwt})
    end

    test "extracts account_id from top-level claim" do
      jwt = build_jwt(%{"chatgpt_account_id" => "acct_456"})

      assert "acct_456" = OpenAIOAuth.extract_account_id_from_tokens(%{id_token: jwt})
    end

    test "extracts account_id from organizations array" do
      jwt = build_jwt(%{"organizations" => [%{"id" => "org_789"}]})

      assert "org_789" = OpenAIOAuth.extract_account_id_from_tokens(%{id_token: jwt})
    end
  end
end
