# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomProvidersTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  setup do: %{scope: Scope.for_user(user_fixture())}

  test "creates one sanitized aggregate with normalized models", %{scope: scope} do
    subscribe_to_config_changes(scope)

    assert {:ok, provider} =
             Providers.create_custom_provider(
               scope,
               valid_attributes(%{"models" => [" zeta ", "Alpha", "beta"]})
             )

    assert provider.models == ["Alpha", "beta", "zeta"]
    refute provider.has_api_key
    assert_receive :config_options_changed

    assert {:ok, %{has_api_key: false}} =
             Providers.create_custom_provider(scope, valid_attributes(%{"api_key" => ""}))
  end

  test "rejects invalid aggregate model lists", %{scope: scope} do
    model_id = String.duplicate("x", 256)

    assert {:ok, %{models: [^model_id]}} =
             Providers.create_custom_provider(scope, valid_attributes(%{"models" => [model_id]}))

    invalid_models = [
      nil,
      ["duplicate", " duplicate "],
      [" "],
      [String.duplicate("x", 257)],
      Enum.map(1..101, &"model-#{&1}")
    ]

    for models <- invalid_models do
      assert {:error, %{models: [_ | _]}} =
               Providers.create_custom_provider(scope, valid_attributes(%{"models" => models}))
    end
  end

  test "validates required and maximum provider fields", %{scope: scope} do
    for {field, value} <- [
          {"name", ""},
          {"name", String.duplicate("x", 65)},
          {"base_url", ""},
          {"base_url", "https://example.com/" <> String.duplicate("x", 493)}
        ] do
      error_field = String.to_existing_atom(field)

      assert {:error, %{^error_field => [_ | _]}} =
               Providers.create_custom_provider(scope, valid_attributes(%{field => value}))
    end
  end

  test "lists only the current user's aggregates", %{scope: scope} do
    attrs = valid_attributes(%{"name" => "shared", "models" => ["model-b"]})
    {:ok, mine} = Providers.create_custom_provider(scope, attrs)
    other_scope = Scope.for_user(user_fixture())
    assert {:ok, _} = Providers.create_custom_provider(other_scope, attrs)
    assert {:error, %{name: [_ | _]}} = Providers.create_custom_provider(scope, attrs)

    assert [%{id: id, models: ["model-b"]}] = Providers.list_custom_providers(scope)
    assert id == mine.id
  end

  test "rejects invalid API-key changes", %{scope: scope} do
    {:ok, provider} = Providers.create_custom_provider(scope, valid_attributes())
    subscribe_to_config_changes(scope)

    assert {:error, %{api_key_change: [_ | _]}} =
             Providers.update_custom_provider(
               scope,
               provider.id,
               replacement(provider, %{"api_key_change" => "keep"})
             )

    refute_receive :config_options_changed, 50
  end

  test "does not expose another user's provider", %{scope: scope} do
    other_scope = Scope.for_user(user_fixture())
    {:ok, provider} = Providers.create_custom_provider(other_scope, valid_attributes())

    assert {:error, :not_found} =
             Providers.update_custom_provider(scope, provider.id, replacement(provider))

    assert {:error, :not_found} =
             Providers.delete_custom_provider(scope, provider.id, provider.lock_version)
  end

  test "stale replacement preserves winner and returns sanitized current aggregate", %{
    scope: scope
  } do
    {:ok, provider} =
      Providers.create_custom_provider(
        scope,
        valid_attributes(%{"name" => "provider", "models" => ["original"]})
      )

    subscribe_to_config_changes(scope)

    assert {:ok, winner} =
             Providers.update_custom_provider(
               scope,
               provider.id,
               replacement(provider, %{"name" => "winner", "models" => ["winner"]})
             )

    assert winner.lock_version == provider.lock_version + 1
    assert_receive :config_options_changed

    assert {:error, {:stale, ^winner}} =
             Providers.update_custom_provider(
               scope,
               provider.id,
               replacement(provider, %{"name" => "loser", "models" => ["loser"]})
             )

    refute_receive :config_options_changed, 50
    assert [^winner] = Providers.list_custom_providers(scope)
  end

  test "stale delete preserves aggregate and publishes no notification", %{scope: scope} do
    {:ok, provider} = Providers.create_custom_provider(scope, valid_attributes())

    {:ok, current} =
      Providers.update_custom_provider(
        scope,
        provider.id,
        replacement(provider, %{"name" => "winner"})
      )

    subscribe_to_config_changes(scope)

    assert {:error, {:stale, ^current}} =
             Providers.delete_custom_provider(scope, provider.id, provider.lock_version)

    refute_receive :config_options_changed, 50
    assert [^current] = Providers.list_custom_providers(scope)

    assert :ok = Providers.delete_custom_provider(scope, provider.id, current.lock_version)
    assert_receive :config_options_changed
  end

  defp valid_attributes(attrs \\ %{}) do
    %{
      "name" => "provider-#{System.unique_integer([:positive])}",
      "base_url" => "https://93.184.216.34/v1",
      "models" => []
    }
    |> Map.merge(attrs)
  end

  defp replacement(provider, attrs \\ %{}) do
    %{
      "name" => provider.name,
      "base_url" => provider.base_url,
      "models" => provider.models,
      "lock_version" => provider.lock_version,
      "api_key_change" => %{"action" => "keep"}
    }
    |> Map.merge(attrs)
  end

  defp subscribe_to_config_changes(scope) do
    Phoenix.PubSub.subscribe(
      FrontmanServer.PubSub,
      Providers.config_pubsub_topic(Scope.user(scope).id)
    )
  end
end
