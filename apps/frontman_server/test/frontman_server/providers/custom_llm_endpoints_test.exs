# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomLlmEndpointsTest do
  @moduledoc """
  Unit tests for the `CustomLlmEndpoints` context.

  Covers user scoping (no cross-user access), CRUD, and delete cascading.
  """

  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers.CustomLlmEndpoints
  alias FrontmanServer.Providers.CustomLlmModel

  setup do
    user = user_fixture()
    %{scope: Scope.for_user(user)}
  end

  describe "create_endpoint/2" do
    test "creates an endpoint without an API key", %{scope: scope} do
      attrs = valid_endpoint_attributes()

      assert {:ok, endpoint} = CustomLlmEndpoints.create_endpoint(scope, attrs)

      assert endpoint.name == attrs.name
      assert endpoint.base_url == attrs.base_url
      assert is_nil(endpoint.api_key)
      assert endpoint.user_id == scope.user.id
    end

    test "creates an endpoint with an API key", %{scope: scope} do
      attrs = valid_endpoint_attributes(api_key: "sk-custom-secret")

      assert {:ok, endpoint} = CustomLlmEndpoints.create_endpoint(scope, attrs)

      assert endpoint.api_key == "sk-custom-secret"
    end
  end

  describe "list_endpoints/1" do
    test "returns only the current user's endpoints", %{scope: scope} do
      {:ok, mine} = CustomLlmEndpoints.create_endpoint(scope, valid_endpoint_attributes())

      other_scope = Scope.for_user(user_fixture())
      {:ok, _} = CustomLlmEndpoints.create_endpoint(other_scope, valid_endpoint_attributes())

      assert [%{id: id}] = CustomLlmEndpoints.list_endpoints(scope)
      assert id == mine.id
    end

    test "preloads models ordered by position then model_id", %{scope: scope} do
      {:ok, endpoint} = CustomLlmEndpoints.create_endpoint(scope, valid_endpoint_attributes())

      {:ok, _} =
        CustomLlmEndpoints.add_model(scope, endpoint.id, %{
          model_id: "zeta",
          position: 10,
          display_name: "Zeta"
        })

      {:ok, _} = CustomLlmEndpoints.add_model(scope, endpoint.id, %{model_id: "gamma"})

      {:ok, _} =
        CustomLlmEndpoints.add_model(scope, endpoint.id, %{model_id: "beta", position: 5})

      {:ok, _} =
        CustomLlmEndpoints.add_model(scope, endpoint.id, %{model_id: "alpha", position: 5})

      assert [ordered] = CustomLlmEndpoints.list_endpoints(scope)
      assert ["alpha", "beta", "zeta", "gamma"] == Enum.map(ordered.models, & &1.model_id)
    end
  end

  describe "update_endpoint/3" do
    test "updates name and base_url", %{scope: scope} do
      {:ok, endpoint} = CustomLlmEndpoints.create_endpoint(scope, valid_endpoint_attributes())

      assert {:ok, updated} =
               CustomLlmEndpoints.update_endpoint(scope, endpoint.id, %{
                 name: "renamed",
                 base_url: "https://api.new.example.com/v1",
                 api_key: "sk-replaced"
               })

      assert updated.name == "renamed"
      assert updated.base_url == "https://api.new.example.com/v1"
      assert updated.api_key == "sk-replaced"
    end

    test "returns :not_found for another user's endpoint", %{scope: scope} do
      other_scope = Scope.for_user(user_fixture())

      {:ok, endpoint} =
        CustomLlmEndpoints.create_endpoint(other_scope, valid_endpoint_attributes())

      assert {:error, :not_found} =
               CustomLlmEndpoints.update_endpoint(scope, endpoint.id, %{name: "hijacked"})
    end
  end

  describe "delete_endpoint/2" do
    test "deletes the endpoint and its models via on_delete: :delete_all", %{scope: scope} do
      {:ok, endpoint} = CustomLlmEndpoints.create_endpoint(scope, valid_endpoint_attributes())

      {:ok, model_a} = CustomLlmEndpoints.add_model(scope, endpoint.id, %{model_id: "model-a"})
      {:ok, model_b} = CustomLlmEndpoints.add_model(scope, endpoint.id, %{model_id: "model-b"})

      assert :ok = CustomLlmEndpoints.delete_endpoint(scope, endpoint.id)

      assert_raise Ecto.NoResultsError, fn ->
        CustomLlmEndpoints.get_endpoint!(scope, endpoint.id)
      end

      assert [] == Repo.all(from(m in CustomLlmModel, where: m.id in ^[model_a.id, model_b.id]))
    end

    test "returns :not_found for another user's endpoint", %{scope: scope} do
      other_scope = Scope.for_user(user_fixture())

      {:ok, endpoint} =
        CustomLlmEndpoints.create_endpoint(other_scope, valid_endpoint_attributes())

      assert {:error, :not_found} = CustomLlmEndpoints.delete_endpoint(scope, endpoint.id)
    end
  end

  describe "add_model/3" do
    test "adds a model to an owned endpoint", %{scope: scope} do
      {:ok, endpoint} = CustomLlmEndpoints.create_endpoint(scope, valid_endpoint_attributes())

      assert {:ok, model} =
               CustomLlmEndpoints.add_model(scope, endpoint.id, %{
                 model_id: "llama-4-scout",
                 display_name: "Llama 4 Scout",
                 position: 0
               })

      assert model.model_id == "llama-4-scout"
      assert model.display_name == "Llama 4 Scout"
      assert model.position == 0
      assert model.endpoint_id == endpoint.id
    end
  end

  describe "remove_model/3" do
    test "removes a single model by model_id", %{scope: scope} do
      {:ok, endpoint} = CustomLlmEndpoints.create_endpoint(scope, valid_endpoint_attributes())
      {:ok, _} = CustomLlmEndpoints.add_model(scope, endpoint.id, %{model_id: "keep-me"})
      {:ok, _} = CustomLlmEndpoints.add_model(scope, endpoint.id, %{model_id: "drop-me"})

      assert :ok = CustomLlmEndpoints.remove_model(scope, endpoint.id, "drop-me")

      assert [remaining] = CustomLlmEndpoints.list_endpoints(scope)
      assert ["keep-me"] == Enum.map(remaining.models, & &1.model_id)
    end

    test "returns :not_found for a model not on the endpoint", %{scope: scope} do
      {:ok, endpoint} = CustomLlmEndpoints.create_endpoint(scope, valid_endpoint_attributes())
      {:ok, _} = CustomLlmEndpoints.add_model(scope, endpoint.id, %{model_id: "present"})

      assert {:error, :not_found} =
               CustomLlmEndpoints.remove_model(scope, endpoint.id, "absent")
    end
  end

  defp unique_endpoint_name, do: "endpoint-#{System.unique_integer([:positive])}"

  defp valid_endpoint_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_endpoint_name(),
      base_url: "https://api.custom-llm.example.com/v1"
    })
  end
end
