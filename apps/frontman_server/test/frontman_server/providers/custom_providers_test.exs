# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomProvidersTest do
  @moduledoc """
  Unit tests for the Custom Provider API on `Providers`.

  Covers user scoping (no cross-user access), CRUD, and delete cascading.
  """

  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  setup do
    user = user_fixture()
    %{scope: Scope.for_user(user)}
  end

  describe "create_custom_provider/2" do
    test "creates a provider without an API key", %{scope: scope} do
      attrs = valid_provider_attributes()

      assert {:ok, provider} = Providers.create_custom_provider(scope, attrs)

      assert provider.name == attrs.name
      assert provider.base_url == attrs.base_url
      assert provider.has_api_key == false
      assert provider.models == []
      refute Map.has_key?(provider, :api_key)
      refute Map.has_key?(provider, :user_id)
    end
  end

  describe "list_custom_providers/1" do
    test "returns only the current user's providers", %{scope: scope} do
      {:ok, mine} = Providers.create_custom_provider(scope, valid_provider_attributes())

      other_scope = Scope.for_user(user_fixture())
      {:ok, _} = Providers.create_custom_provider(other_scope, valid_provider_attributes())

      assert [%{id: id}] = Providers.list_custom_providers(scope)
      assert id == mine.id
    end

    test "preloads models ordered by model_id", %{scope: scope} do
      {:ok, provider} = Providers.create_custom_provider(scope, valid_provider_attributes())

      {:ok, _} =
        Providers.add_custom_provider_model(scope, provider.id, %{
          model_id: "zeta",
          position: 0,
          display_name: "ignored"
        })

      {:ok, _} =
        Providers.add_custom_provider_model(scope, provider.id, %{model_id: "gamma", position: 1})

      {:ok, _} =
        Providers.add_custom_provider_model(scope, provider.id, %{model_id: "beta", position: 10})

      {:ok, _} =
        Providers.add_custom_provider_model(scope, provider.id, %{model_id: "alpha", position: 20})

      assert [ordered] = Providers.list_custom_providers(scope)
      assert ["alpha", "beta", "gamma", "zeta"] == Enum.map(ordered.models, & &1.model_id)
    end
  end

  describe "update_custom_provider/3" do
    test "returns :not_found for another user's provider", %{scope: scope} do
      other_scope = Scope.for_user(user_fixture())

      {:ok, provider} =
        Providers.create_custom_provider(other_scope, valid_provider_attributes())

      assert {:error, :not_found} =
               Providers.update_custom_provider(scope, provider.id, %{name: "hijacked"})
    end

    test "create and update reject non-public base URLs", %{scope: scope} do
      assert {:error, create_changeset} =
               Providers.create_custom_provider(
                 scope,
                 valid_provider_attributes(base_url: "http://127.0.0.1")
               )

      {:ok, provider} = Providers.create_custom_provider(scope, valid_provider_attributes())

      assert {:error, update_errors} =
               Providers.update_custom_provider(scope, provider.id, %{base_url: "http://10.0.0.1"})

      for errors <- [create_changeset, update_errors] do
        assert Enum.any?(errors.base_url, &String.starts_with?(&1, "Requests to private"))
      end
    end
  end

  describe "delete_custom_provider/2" do
    test "deletes the provider", %{scope: scope} do
      {:ok, provider} = Providers.create_custom_provider(scope, valid_provider_attributes())

      {:ok, _} = Providers.add_custom_provider_model(scope, provider.id, %{model_id: "model-a"})
      {:ok, _} = Providers.add_custom_provider_model(scope, provider.id, %{model_id: "model-b"})

      assert :ok = Providers.delete_custom_provider(scope, provider.id)
      assert Providers.list_custom_providers(scope) == []
    end

    test "returns :not_found for another user's provider", %{scope: scope} do
      other_scope = Scope.for_user(user_fixture())

      {:ok, provider} =
        Providers.create_custom_provider(other_scope, valid_provider_attributes())

      assert {:error, :not_found} = Providers.delete_custom_provider(scope, provider.id)
    end
  end

  describe "add_custom_provider_model/3" do
    test "adds a model to an owned provider", %{scope: scope} do
      {:ok, provider} = Providers.create_custom_provider(scope, valid_provider_attributes())

      assert {:ok, updated_provider} =
               Providers.add_custom_provider_model(scope, provider.id, %{
                 model_id: "llama-4-scout"
               })

      assert [%{id: _, model_id: "llama-4-scout"}] = updated_provider.models
    end

    test "rejects duplicate model IDs on one provider", %{scope: scope} do
      {:ok, provider} = Providers.create_custom_provider(scope, valid_provider_attributes())
      attrs = %{model_id: "llama-4-scout"}

      assert {:ok, _provider} = Providers.add_custom_provider_model(scope, provider.id, attrs)
      assert {:error, errors} = Providers.add_custom_provider_model(scope, provider.id, attrs)
      assert "has already been taken" in errors.model_id
    end

    test "allows the same model ID on different providers", %{scope: scope} do
      {:ok, first} = Providers.create_custom_provider(scope, valid_provider_attributes())
      {:ok, second} = Providers.create_custom_provider(scope, valid_provider_attributes())
      attrs = %{model_id: "llama-4-scout"}

      assert {:ok, _provider} = Providers.add_custom_provider_model(scope, first.id, attrs)
      assert {:ok, _provider} = Providers.add_custom_provider_model(scope, second.id, attrs)
    end
  end

  describe "remove_custom_provider_model/3" do
    test "returns :not_found for another user's model", %{scope: scope} do
      other_scope = Scope.for_user(user_fixture())
      {:ok, provider} = Providers.create_custom_provider(other_scope, valid_provider_attributes())

      {:ok, updated_provider} =
        Providers.add_custom_provider_model(other_scope, provider.id, %{model_id: "private"})

      [%{id: model_id}] = updated_provider.models

      assert {:error, :not_found} =
               Providers.remove_custom_provider_model(scope, provider.id, model_id)
    end
  end

  defp unique_provider_name, do: "provider-#{System.unique_integer([:positive])}"

  defp valid_provider_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_provider_name(),
      base_url: "https://93.184.216.34/v1"
    })
  end
end
