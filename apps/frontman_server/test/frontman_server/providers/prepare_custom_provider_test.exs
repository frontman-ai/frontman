defmodule FrontmanServer.Providers.PrepareCustomProviderTest do
  @moduledoc """
  Tests for custom-provider integration in `FrontmanServer.Providers`:
  picker groups in `available_models/1`, LLM access resolution for
  `"custom:<provider_id>:<model_id>"` strings via `resolve_model_access/3`,
  and validation in `parse_model_ref/1`.
  """
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  setup do
    user = user_fixture()
    scope = %Scope{user: user}
    {:ok, scope: scope}
  end

  describe "available_models/1 with custom providers" do
    test "includes each custom provider as a group with one option per model", %{scope: scope} do
      provider_a = provider_fixture(scope, %{"name" => "Alpha"})
      provider_b = provider_fixture(scope, %{"name" => "Beta"})

      add_model(scope, provider_a.id, "m-one")
      add_model(scope, provider_b.id, "m-two")

      config = Providers.available_models(scope)

      group_a = find_group(config.groups, provider_a.id)
      group_b = find_group(config.groups, provider_b.id)

      assert group_a.id == "custom:#{provider_a.id}"
      assert group_a.name == "Alpha"
      assert group_a.options == [%{name: "m-one", value: "custom:#{provider_a.id}:m-one"}]

      assert group_b.id == "custom:#{provider_b.id}"
      assert group_b.name == "Beta"
      assert group_b.options == [%{name: "m-two", value: "custom:#{provider_b.id}:m-two"}]
    end

    test "orders models by model_id and omits providers with no models", %{
      scope: scope
    } do
      provider = provider_fixture(scope)
      empty_provider = provider_fixture(scope, %{"name" => "Empty"})

      {:ok, _} =
        Providers.add_custom_provider_model(scope, provider.id, %{model_id: "m-b", position: 1})

      {:ok, _} =
        Providers.add_custom_provider_model(scope, provider.id, %{model_id: "m-a", position: 2})

      {:ok, _} =
        Providers.add_custom_provider_model(scope, provider.id, %{model_id: "m-zero", position: 0})

      config = Providers.available_models(scope)

      assert [%{options: [%{name: "m-a"}, %{name: "m-b"}, %{name: "m-zero"}]}] = config.groups

      refute Enum.any?(config.groups, &(&1.id == "custom:#{empty_provider.id}"))
    end
  end

  describe "resolve_model_access/3 with custom providers" do
    test "resolves a custom provider model to a base_url on the LLMDB.Model", %{scope: scope} do
      provider = provider_fixture(scope)
      add_model(scope, provider.id, "gpt-custom")

      {:ok, {model, llm_opts}} =
        Providers.resolve_model_access(scope, "custom:#{provider.id}:gpt-custom")

      assert %LLMDB.Model{provider: :openai, id: "gpt-custom"} = model
      assert model.base_url == "http://93.184.216.34:8000/v1"
      assert llm_opts[:api_key] == "sk-no-key-required"
      assert llm_opts[:req_http_options] == [plugins: [FrontmanServer.PublicURL], redirect: false]
      assert is_function(llm_opts[:on_finch_request], 1)
    end

    test "includes the provider's api_key in llm_opts when set", %{scope: scope} do
      provider =
        provider_fixture(scope, %{
          "base_url" => "http://93.184.216.35:8000/v1",
          "api_key" => "secret-key"
        })

      add_model(scope, provider.id, "gpt-custom")

      {:ok, {_model, llm_opts}} =
        Providers.resolve_model_access(scope, "custom:#{provider.id}:gpt-custom")

      assert llm_opts[:api_key] == "secret-key"
    end

    test "resolves the current URL and preserved, replaced, or removed API key", %{scope: scope} do
      provider = provider_fixture(scope, %{"api_key" => "original-key"})
      add_model(scope, provider.id, "gpt-custom")
      model_ref = "custom:#{provider.id}:gpt-custom"

      assert {:ok, _} =
               Providers.update_custom_provider(scope, provider.id, %{
                 "base_url" => "https://93.184.216.35/v1"
               })

      assert {:ok, {%{base_url: "https://93.184.216.35/v1"}, llm_opts}} =
               Providers.resolve_model_access(scope, model_ref)

      assert llm_opts[:api_key] == "original-key"

      assert {:ok, _} =
               Providers.update_custom_provider(scope, provider.id, %{
                 "api_key" => "replacement-key"
               })

      assert {:ok, {_, llm_opts}} = Providers.resolve_model_access(scope, model_ref)
      assert llm_opts[:api_key] == "replacement-key"

      assert {:ok, _} = Providers.update_custom_provider(scope, provider.id, %{"api_key" => ""})

      assert {:ok, {_, llm_opts}} = Providers.resolve_model_access(scope, model_ref)
      assert llm_opts[:api_key] == "sk-no-key-required"
    end

    test "returns :unknown_model for another user's provider", %{scope: scope} do
      other_scope = %Scope{user: user_fixture()}
      provider = provider_fixture(other_scope)
      add_model(other_scope, provider.id, "gpt-custom")

      assert {:error, :unknown_model} =
               Providers.resolve_model_access(scope, "custom:#{provider.id}:gpt-custom")
    end

    test "returns :unknown_model for an unknown model_id on an owned provider", %{scope: scope} do
      provider = provider_fixture(scope)
      add_model(scope, provider.id, "gpt-custom")

      assert {:error, :unknown_model} =
               Providers.resolve_model_access(scope, "custom:#{provider.id}:other-model")
    end

    test "returns :unknown_model for a malformed provider id", %{scope: scope} do
      assert {:error, :unknown_model} =
               Providers.resolve_model_access(scope, "custom:not-a-uuid:gpt-custom")
    end
  end

  describe "parse_model_ref/1" do
    test "accepts custom:<id>:<model>" do
      assert {:ok, "custom:abc-123:gpt-x"} =
               Providers.parse_model_ref("custom:abc-123:gpt-x")
    end

    test "rejects incomplete custom references" do
      assert :error = Providers.parse_model_ref("custom:abc-123")
    end

    test "accepts catalog references" do
      assert {:ok, "anthropic:claude-sonnet-5"} =
               Providers.parse_model_ref("anthropic:claude-sonnet-5")
    end
  end

  defp provider_fixture(scope, attrs \\ %{}) do
    {:ok, provider} =
      Providers.create_custom_provider(
        scope,
        Map.merge(%{"name" => "vLLM", "base_url" => "http://93.184.216.34:8000/v1"}, attrs)
      )

    provider
  end

  defp add_model(scope, provider_id, model_id) do
    {:ok, _model} =
      Providers.add_custom_provider_model(scope, provider_id, %{"model_id" => model_id})

    :ok
  end

  defp find_group(groups, provider_id) do
    Enum.find(groups, &(&1.id == "custom:#{provider_id}"))
  end
end
