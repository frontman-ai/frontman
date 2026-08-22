# Frontman Server
# Copyright (C) 2025 Frontman AI
# Licensed under the AGPL-3.0 — see LICENSE for details.

defmodule FrontmanServerWeb.CustomLlmEndpointsControllerTest do
  @moduledoc """
  Controller-level acceptance tests for user-defined OpenAI-compatible
  LLM endpoints under `/api/user/custom-endpoints`.
  """

  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Providers
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  @llm_provider_env_vars [
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "OPENROUTER_API_KEY",
    "FIREWORKS_API_KEY",
    "NVIDIA_API_KEY"
  ]

  describe "POST /api/user/custom-endpoints" do
    setup :register_and_log_in_user

    test "acceptance #1: a user can create multiple endpoints", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/custom-endpoints", %{
          "name" => "vLLM",
          "base_url" => "http://localhost:8000/v1"
        })

      assert %{"endpoint" => %{"id" => id_a, "name" => "vLLM"}} = json_response(conn, 200)

      conn =
        post(conn, ~p"/api/user/custom-endpoints", %{
          "name" => "LM Studio",
          "base_url" => "http://localhost:1234/v1"
        })

      assert %{"endpoint" => %{"id" => id_b}} = json_response(conn, 200)
      refute id_a == id_b

      conn = get(conn, ~p"/api/user/custom-endpoints")
      assert %{"endpoints" => endpoints} = json_response(conn, 200)
      assert length(endpoints) == 2
      assert endpoints |> Enum.map(& &1["name"]) |> Enum.sort() == ["LM Studio", "vLLM"]
    end

    test "acceptance #3: endpoints may omit api_key and the value is never returned", %{
      conn: conn
    } do
      conn =
        post(conn, ~p"/api/user/custom-endpoints", %{
          "name" => "vLLM",
          "base_url" => "http://localhost:8000/v1"
        })

      assert %{"endpoint" => endpoint} = json_response(conn, 200)
      assert endpoint["has_api_key"] == false
      refute Map.has_key?(endpoint, "api_key")

      conn = get(conn, ~p"/api/user/custom-endpoints")
      assert %{"endpoints" => [endpoint]} = json_response(conn, 200)
      assert endpoint["has_api_key"] == false
      refute Map.has_key?(endpoint, "api_key")
    end

    test "acceptance #3: a saved api_key is never echoed back in any payload", %{conn: conn} do
      secret = "sk-custom-secret-value"

      conn =
        post(conn, ~p"/api/user/custom-endpoints", %{
          "name" => "vLLM",
          "base_url" => "http://localhost:8000/v1",
          "api_key" => secret
        })

      assert %{"endpoint" => endpoint} = json_response(conn, 200)
      assert endpoint["has_api_key"] == true
      refute Map.has_key?(endpoint, "api_key")
      refute conn.resp_body =~ secret

      conn = get(conn, ~p"/api/user/custom-endpoints")
      assert %{"endpoints" => [endpoint]} = json_response(conn, 200)
      assert endpoint["has_api_key"] == true
      refute Map.has_key?(endpoint, "api_key")
      refute conn.resp_body =~ secret
    end

    test "broadcasts :config_options_changed after successful create", %{
      conn: conn,
      user: user
    } do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Providers.config_pubsub_topic(user.id))

      conn =
        post(conn, ~p"/api/user/custom-endpoints", %{
          "name" => "vLLM",
          "base_url" => "http://localhost:8000/v1"
        })

      assert %{"endpoint" => %{}} = json_response(conn, 200)
      assert_receive :config_options_changed, 100
    end

    test "does not broadcast on validation failure", %{conn: conn, user: user} do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Providers.config_pubsub_topic(user.id))

      conn =
        post(conn, ~p"/api/user/custom-endpoints", %{
          "name" => "",
          "base_url" => "http://localhost:8000/v1"
        })

      assert %{"status" => "error"} = json_response(conn, 422)
      refute_receive :config_options_changed, 100
    end

    test "returns unauthorized without user" do
      conn = build_conn()

      conn =
        post(conn, ~p"/api/user/custom-endpoints", %{
          "name" => "vLLM",
          "base_url" => "http://localhost:8000/v1"
        })

      assert json_response(conn, 401)["error"] == "authentication_required"
    end
  end

  describe "POST /api/user/custom-endpoints/:id/models" do
    setup :register_and_log_in_user

    test "acceptance #2: an endpoint can hold multiple models", %{conn: conn} do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      conn = post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "qwen-3"})
      assert %{"model" => %{"model_id" => "qwen-3"}} = json_response(conn, 200)

      conn =
        post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "llama-4-scout"})

      assert %{"model" => %{"model_id" => "llama-4-scout"}} = json_response(conn, 200)

      conn = get(conn, ~p"/api/user/custom-endpoints")
      assert %{"endpoints" => [endpoint]} = json_response(conn, 200)
      assert length(endpoint["models"]) == 2

      assert endpoint["models"] |> Enum.map(& &1["model_id"]) |> Enum.sort() == [
               "llama-4-scout",
               "qwen-3"
             ]
    end

    test "broadcasts :config_options_changed after adding a model", %{conn: conn, user: user} do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Providers.config_pubsub_topic(user.id))

      conn = post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "qwen-3"})
      assert %{"model" => %{}} = json_response(conn, 200)
      assert_receive :config_options_changed, 100
    end
  end

  describe "DELETE /api/user/custom-endpoints/:id" do
    setup :register_and_log_in_user

    test "broadcasts :config_options_changed after deleting an endpoint", %{
      conn: conn,
      user: user
    } do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Providers.config_pubsub_topic(user.id))

      conn = delete(conn, ~p"/api/user/custom-endpoints/#{id}")
      assert %{"status" => "ok"} = json_response(conn, 200)
      assert_receive :config_options_changed, 100
    end
  end

  describe "provider picker integration" do
    setup :register_and_log_in_user

    test "acceptance #4: saved endpoint + model appear as a picker group", %{
      conn: conn,
      scope: scope
    } do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      conn =
        post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "gpt-custom"})

      assert json_response(conn, 200)

      assert %{groups: groups} = Providers.model_config_data(scope)

      group = Enum.find(groups, &(&1.id == "custom:#{id}"))
      assert group.name == "vLLM"
      assert group.options == [%{name: "gpt-custom", value: "custom:#{id}:gpt-custom"}]
    end

    test "acceptance #6: deleting an endpoint removes its models and picker group", %{
      conn: conn,
      scope: scope
    } do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      conn =
        post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "gpt-custom"})

      assert json_response(conn, 200)

      assert %{groups: groups} = Providers.model_config_data(scope)
      assert Enum.any?(groups, &(&1.id == "custom:#{id}"))

      conn = delete(conn, ~p"/api/user/custom-endpoints/#{id}")
      assert %{"status" => "ok"} = json_response(conn, 200)

      assert %{groups: groups_after} = Providers.model_config_data(scope)
      refute Enum.any?(groups_after, &(&1.id == "custom:#{id}"))

      conn = get(conn, ~p"/api/user/custom-endpoints")
      assert %{"endpoints" => []} = json_response(conn, 200)
    end
  end

  describe "request routing integration" do
    setup :register_and_log_in_user

    test "acceptance #5: requests target the correct endpoint base_url and api_key", %{
      conn: conn,
      scope: scope
    } do
      conn =
        post(conn, ~p"/api/user/custom-endpoints", %{
          "name" => "vLLM",
          "base_url" => "http://vllm:8000/v1",
          "api_key" => "sk-vllm-secret"
        })

      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      conn =
        post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "gpt-custom"})

      assert json_response(conn, 200)

      assert {:ok, {%LLMDB.Model{provider: :openai, id: "gpt-custom"} = model, llm_opts}} =
               Providers.prepare_llm_args(scope, "custom:#{id}:gpt-custom")

      assert model.base_url == "http://vllm:8000/v1"
      assert llm_opts[:api_key] == "sk-vllm-secret"
    end
  end

  describe "user isolation" do
    setup :register_and_log_in_user

    test "acceptance #7: users cannot see or mutate another user's endpoints", %{conn: conn} do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      other_conn = log_in_user(build_conn(), AccountsFixtures.user_fixture())

      other_conn = get(other_conn, ~p"/api/user/custom-endpoints")
      assert %{"endpoints" => []} = json_response(other_conn, 200)

      other_conn =
        patch(other_conn, ~p"/api/user/custom-endpoints/#{id}", %{"name" => "hijacked"})

      assert %{"status" => "error", "error" => "not_found"} = json_response(other_conn, 404)

      other_conn = delete(other_conn, ~p"/api/user/custom-endpoints/#{id}")
      assert %{"status" => "error", "error" => "not_found"} = json_response(other_conn, 404)

      conn = get(conn, ~p"/api/user/custom-endpoints")
      assert [%{"id" => ^id}] = json_response(conn, 200)["endpoints"]
    end
  end

  describe "PATCH /api/user/custom-endpoints/:id" do
    setup :register_and_log_in_user

    test "updates name and base_url", %{conn: conn} do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      conn =
        patch(conn, ~p"/api/user/custom-endpoints/#{id}", %{
          "name" => "renamed",
          "base_url" => "https://new.example.com/v1"
        })

      assert %{"endpoint" => %{"name" => "renamed", "base_url" => "https://new.example.com/v1"}} =
               json_response(conn, 200)
    end

    test "broadcasts :config_options_changed after successful update", %{
      conn: conn,
      user: user
    } do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Providers.config_pubsub_topic(user.id))

      conn = patch(conn, ~p"/api/user/custom-endpoints/#{id}", %{"name" => "renamed"})
      assert %{"endpoint" => %{}} = json_response(conn, 200)
      assert_receive :config_options_changed, 100
    end
  end

  describe "DELETE /api/user/custom-endpoints/:id/models/:model_id" do
    setup :register_and_log_in_user

    test "removes a single model from the endpoint", %{conn: conn} do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      conn = post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "keep-me"})
      assert json_response(conn, 200)

      conn = post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "drop-me"})
      assert json_response(conn, 200)

      conn = delete(conn, ~p"/api/user/custom-endpoints/#{id}/models/drop-me")
      assert %{"status" => "ok"} = json_response(conn, 200)

      conn = get(conn, ~p"/api/user/custom-endpoints")
      assert [%{"models" => [%{"model_id" => "keep-me"}]}] = json_response(conn, 200)["endpoints"]
    end

    test "broadcasts :config_options_changed after removing a model", %{conn: conn, user: user} do
      conn = create_endpoint(conn)
      %{"endpoint" => %{"id" => id}} = json_response(conn, 200)

      conn = post(conn, ~p"/api/user/custom-endpoints/#{id}/models", %{"model_id" => "drop-me"})
      assert json_response(conn, 200)

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Providers.config_pubsub_topic(user.id))

      conn = delete(conn, ~p"/api/user/custom-endpoints/#{id}/models/drop-me")
      assert %{"status" => "ok"} = json_response(conn, 200)
      assert_receive :config_options_changed, 100
    end
  end

  describe "config env-var audit" do
    test "acceptance #8: config files contain no LLM provider env-var credential paths" do
      config_dir = Path.expand("../../../config", __DIR__)
      files = Path.wildcard(Path.join(config_dir, "*.exs"))
      assert length(files) > 0

      for file <- files do
        contents = File.read!(file)

        for var <- @llm_provider_env_vars do
          refute contents =~ var,
                 "#{Path.basename(file)} must not reference #{var}: provider credentials " <>
                   "must come from the user, never from environment variables"
        end
      end
    end
  end

  defp create_endpoint(conn, attrs \\ %{}) do
    post(
      conn,
      ~p"/api/user/custom-endpoints",
      Map.merge(%{"name" => "vLLM", "base_url" => "http://localhost:8000/v1"}, attrs)
    )
  end
end
