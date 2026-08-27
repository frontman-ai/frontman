# Frontman Server
# Copyright (C) 2025 Frontman AI
# Licensed under the AGPL-3.0 — see LICENSE for details.

defmodule FrontmanServerWeb.CustomProvidersControllerTest do
  @moduledoc """
  Controller-level acceptance tests for user-defined OpenAI-compatible
  Custom Providers under `/api/user/custom-providers`.
  """

  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Providers
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  describe "POST /api/user/custom-providers" do
    setup :register_and_log_in_user

    test "acceptance #3: a saved api_key is never echoed back in any payload", %{conn: conn} do
      secret = "sk-custom-secret-value"

      conn =
        post(conn, ~p"/api/user/custom-providers", %{
          "name" => "vLLM",
          "base_url" => "http://93.184.216.34:8000/v1",
          "api_key" => secret
        })

      assert %{"provider" => provider} = json_response(conn, 200)
      assert provider["has_api_key"] == true
      refute Map.has_key?(provider, "api_key")
      refute conn.resp_body =~ secret

      conn = get(conn, ~p"/api/user/custom-providers")
      assert %{"providers" => [provider]} = json_response(conn, 200)
      assert provider["has_api_key"] == true
      refute Map.has_key?(provider, "api_key")
      refute conn.resp_body =~ secret
    end

    test "broadcasts :config_options_changed after every successful mutation", %{
      conn: conn,
      user: user
    } do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Providers.config_pubsub_topic(user.id))

      conn = create_provider(conn)
      assert %{"provider" => %{"id" => id}} = json_response(conn, 200)
      assert_receive :config_options_changed, 100

      conn = patch(conn, ~p"/api/user/custom-providers/#{id}", %{"name" => "renamed"})
      assert %{"provider" => %{}} = json_response(conn, 200)
      assert_receive :config_options_changed, 100

      conn = post(conn, ~p"/api/user/custom-providers/#{id}/models", %{"model_id" => "model"})
      assert %{"provider" => %{"models" => [%{"id" => model_id}]}} = json_response(conn, 200)
      assert_receive :config_options_changed, 100

      conn = delete(conn, ~p"/api/user/custom-providers/#{id}/models/#{model_id}")
      assert %{"provider" => %{}} = json_response(conn, 200)
      assert_receive :config_options_changed, 100

      conn = delete(conn, ~p"/api/user/custom-providers/#{id}")
      assert %{"status" => "ok"} = json_response(conn, 200)
      assert_receive :config_options_changed, 100
    end

    test "does not broadcast on validation failure", %{conn: conn, user: user} do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Providers.config_pubsub_topic(user.id))

      conn =
        post(conn, ~p"/api/user/custom-providers", %{
          "name" => "",
          "base_url" => "http://93.184.216.34:8000/v1"
        })

      assert %{"status" => "error"} = json_response(conn, 422)
      refute_receive :config_options_changed, 100
    end

    test "returns unauthorized without user" do
      conn = build_conn()

      conn =
        post(conn, ~p"/api/user/custom-providers", %{
          "name" => "vLLM",
          "base_url" => "http://93.184.216.34:8000/v1"
        })

      assert json_response(conn, 401)["error"] == "authentication_required"
    end
  end

  describe "user isolation" do
    setup :register_and_log_in_user

    test "acceptance #7: users cannot see or mutate another user's providers", %{conn: conn} do
      conn = create_provider(conn)
      %{"provider" => %{"id" => id}} = json_response(conn, 200)

      other_conn = log_in_user(build_conn(), AccountsFixtures.user_fixture())

      other_conn = get(other_conn, ~p"/api/user/custom-providers")
      assert %{"providers" => []} = json_response(other_conn, 200)

      other_conn =
        patch(other_conn, ~p"/api/user/custom-providers/#{id}", %{"name" => "hijacked"})

      assert %{"status" => "error", "error" => "not_found"} = json_response(other_conn, 404)

      other_conn =
        post(other_conn, ~p"/api/user/custom-providers/#{id}/models", %{"model_id" => "private"})

      assert %{"status" => "error", "error" => "not_found"} = json_response(other_conn, 404)

      other_conn = delete(other_conn, ~p"/api/user/custom-providers/#{id}")
      assert %{"status" => "error", "error" => "not_found"} = json_response(other_conn, 404)

      conn = get(conn, ~p"/api/user/custom-providers")
      assert [%{"id" => ^id}] = json_response(conn, 200)["providers"]
    end

    test "returns not found for a malformed provider ID", %{conn: conn} do
      conn = patch(conn, ~p"/api/user/custom-providers/not-a-uuid", %{"name" => "renamed"})

      assert %{"status" => "error", "error" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "PATCH /api/user/custom-providers/:id" do
    setup :register_and_log_in_user

    test "updates fields and clears the API key", %{conn: conn} do
      conn = create_provider(conn, %{"api_key" => "secret"})
      %{"provider" => %{"id" => id, "has_api_key" => true}} = json_response(conn, 200)

      conn =
        patch(conn, ~p"/api/user/custom-providers/#{id}", %{
          "name" => "renamed",
          "base_url" => "https://93.184.216.35/v1",
          "api_key" => ""
        })

      assert %{"provider" => provider} = json_response(conn, 200)
      assert provider["name"] == "renamed"
      assert provider["base_url"] == "https://93.184.216.35/v1"
      refute provider["has_api_key"]
    end
  end

  describe "DELETE /api/user/custom-providers/:id/models/:provider_model_id" do
    setup :register_and_log_in_user

    test "removes a single model from the provider", %{conn: conn} do
      conn = create_provider(conn)
      %{"provider" => %{"id" => id}} = json_response(conn, 200)

      conn = post(conn, ~p"/api/user/custom-providers/#{id}/models", %{"model_id" => "keep-me"})
      assert json_response(conn, 200)

      conn =
        post(conn, ~p"/api/user/custom-providers/#{id}/models", %{"model_id" => "drop/me?#%"})

      %{"provider" => %{"models" => models}} = json_response(conn, 200)
      %{"id" => model_id} = Enum.find(models, &(&1["model_id"] == "drop/me?#%"))

      conn = delete(conn, ~p"/api/user/custom-providers/#{id}/models/#{model_id}")

      assert %{"provider" => %{"models" => [%{"model_id" => "keep-me"}]}} =
               json_response(conn, 200)
    end

    test "returns not found for a malformed provider model ID", %{conn: conn} do
      conn = create_provider(conn)
      %{"provider" => %{"id" => id}} = json_response(conn, 200)

      conn = delete(conn, ~p"/api/user/custom-providers/#{id}/models/not-a-uuid")

      assert %{"status" => "error", "error" => "not_found"} = json_response(conn, 404)
    end
  end

  defp create_provider(conn, attrs \\ %{}) do
    post(
      conn,
      ~p"/api/user/custom-providers",
      Map.merge(%{"name" => "vLLM", "base_url" => "http://93.184.216.34:8000/v1"}, attrs)
    )
  end
end
