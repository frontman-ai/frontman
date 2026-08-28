defmodule FrontmanServer.Providers.PrepareCustomProviderTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  setup do: {:ok, scope: Scope.for_user(user_fixture())}

  describe "available_models/1 with custom providers" do
    test "includes configured models and omits empty providers", %{scope: scope} do
      alpha = provider_fixture(scope, %{"name" => "Alpha", "models" => ["m-one"]})
      empty = provider_fixture(scope, %{"name" => "Empty"})

      groups = Providers.available_models(scope).groups

      assert find_group(groups, alpha.id) == %{
               id: "custom:#{alpha.id}",
               name: "Alpha",
               options: [%{name: "m-one", value: "custom:#{alpha.id}:m-one"}]
             }

      refute find_group(groups, empty.id)
    end
  end

  describe "resolve_model_access/3 with custom providers" do
    test "resolves configured models with protected transport options", %{scope: scope} do
      provider = provider_fixture(scope, %{"models" => ["gpt-custom"]})

      assert {:ok, {%LLMDB.Model{} = model, llm_opts}} =
               Providers.resolve_model_access(scope, "custom:#{provider.id}:gpt-custom")

      assert model.provider == :openai
      assert model.id == "gpt-custom"
      assert model.base_url == "http://93.184.216.34:8000/v1"
      assert llm_opts[:api_key] == "sk-no-key-required"
      assert llm_opts[:req_http_options] == [plugins: [FrontmanServer.PublicURL], redirect: false]
      assert is_function(llm_opts[:on_finch_request], 1)
    end

    test "uses the current URL and explicit API-key changes", %{scope: scope} do
      provider =
        provider_fixture(scope, %{"api_key" => "original", "models" => ["gpt-custom"]})

      model_ref = "custom:#{provider.id}:gpt-custom"

      assert {:ok, kept} =
               Providers.update_custom_provider(
                 scope,
                 provider.id,
                 replacement(provider, %{
                   "base_url" => "https://93.184.216.35/v1",
                   "api_key" => "ignored",
                   "api_key_change" => %{"action" => "keep"}
                 })
               )

      assert {:ok, {%{base_url: "https://93.184.216.35/v1"}, opts}} =
               Providers.resolve_model_access(scope, model_ref)

      assert opts[:api_key] == "original"

      assert {:ok, replaced} =
               Providers.update_custom_provider(
                 scope,
                 provider.id,
                 replacement(kept, %{
                   "api_key_change" => %{"action" => "replace", "value" => "replacement"}
                 })
               )

      assert {:ok, {_, opts}} = Providers.resolve_model_access(scope, model_ref)
      assert opts[:api_key] == "replacement"

      assert {:ok, _cleared} =
               Providers.update_custom_provider(
                 scope,
                 provider.id,
                 replacement(replaced, %{"api_key_change" => %{"action" => "clear"}})
               )

      assert {:ok, {_, opts}} = Providers.resolve_model_access(scope, model_ref)
      assert opts[:api_key] == "sk-no-key-required"
    end

    test "rejects unconfigured, foreign, and malformed references", %{scope: scope} do
      provider = provider_fixture(scope, %{"models" => ["configured"]})
      other = provider_fixture(Scope.for_user(user_fixture()), %{"models" => ["private"]})

      assert {:error, :unknown_model} =
               Providers.resolve_model_access(scope, "custom:#{provider.id}:other")

      assert {:error, :unknown_model} =
               Providers.resolve_model_access(scope, "custom:#{other.id}:private")

      assert {:error, :unknown_model} =
               Providers.resolve_model_access(scope, "custom:not-a-uuid:configured")
    end
  end

  defp provider_fixture(scope, attrs) do
    {:ok, provider} =
      Providers.create_custom_provider(
        scope,
        Map.merge(
          %{"name" => "vLLM", "base_url" => "http://93.184.216.34:8000/v1", "models" => []},
          attrs
        )
      )

    provider
  end

  defp replacement(provider, attrs) do
    Map.merge(
      %{
        "name" => provider.name,
        "base_url" => provider.base_url,
        "models" => provider.models,
        "lock_version" => provider.lock_version,
        "api_key_change" => %{"action" => "keep"}
      },
      attrs
    )
  end

  defp find_group(groups, provider_id) do
    Enum.find(groups, &(&1.id == "custom:#{provider_id}"))
  end
end
