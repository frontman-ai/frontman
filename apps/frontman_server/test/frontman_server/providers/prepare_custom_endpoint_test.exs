defmodule FrontmanServer.Providers.PrepareCustomEndpointTest do
  @moduledoc """
  Tests for custom-endpoint integration in `FrontmanServer.Providers`:
  picker groups in `model_config_data/1`, LLM arg resolution for
  `"custom:<endpoint_id>:<model_id>"` strings via `prepare_llm_args/3`,
  and pass-through in `model_from_client_params/1`.
  """
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.CustomLlmEndpoints

  setup do
    user = user_fixture()
    scope = %Scope{user: user}
    {:ok, scope: scope}
  end

  describe "model_config_data/1 with custom endpoints" do
    test "includes each custom endpoint as a group with one option per model", %{scope: scope} do
      endpoint_a = endpoint_fixture(scope, %{"name" => "Alpha"})
      endpoint_b = endpoint_fixture(scope, %{"name" => "Beta"})

      add_model(scope, endpoint_a.id, "m-one", 1)
      add_model(scope, endpoint_b.id, "m-two", nil)

      config = Providers.model_config_data(scope)

      group_a = find_group(config.groups, endpoint_a.id)
      group_b = find_group(config.groups, endpoint_b.id)

      assert group_a.id == "custom:#{endpoint_a.id}"
      assert group_a.name == "Alpha"
      assert group_a.options == [%{name: "m-one", value: "custom:#{endpoint_a.id}:m-one"}]

      assert group_b.id == "custom:#{endpoint_b.id}"
      assert group_b.name == "Beta"
      assert group_b.options == [%{name: "m-two", value: "custom:#{endpoint_b.id}:m-two"}]
    end

    test "uses 'custom:<endpoint_id>' as the group id", %{scope: scope} do
      endpoint = endpoint_fixture(scope)
      add_model(scope, endpoint.id, "m-one", nil)

      config = Providers.model_config_data(scope)

      assert Enum.any?(config.groups, &(&1.id == "custom:#{endpoint.id}"))
    end

    test "orders models by position then model_id and omits endpoints with no models", %{
      scope: scope
    } do
      endpoint = endpoint_fixture(scope)
      empty_endpoint = endpoint_fixture(scope, %{"name" => "Empty"})

      add_model(scope, endpoint.id, "m-b", 2)
      add_model(scope, endpoint.id, "m-a", 1)
      add_model(scope, endpoint.id, "m-zero", nil)

      config = Providers.model_config_data(scope)

      assert [%{options: [%{name: "m-zero"}, %{name: "m-a"}, %{name: "m-b"}]}] = config.groups

      refute Enum.any?(config.groups, &(&1.id == "custom:#{empty_endpoint.id}"))
    end
  end

  describe "prepare_llm_args/3 with custom endpoints" do
    test "resolves a custom endpoint model to a base_url on the LLMDB.Model", %{scope: scope} do
      endpoint = endpoint_fixture(scope)
      add_model(scope, endpoint.id, "gpt-custom", nil)

      {:ok, {model, llm_opts}} =
        Providers.prepare_llm_args(scope, "custom:#{endpoint.id}:gpt-custom")

      assert %LLMDB.Model{provider: :openai, id: "gpt-custom"} = model
      assert model.base_url == "http://localhost:8000/v1"
      assert llm_opts == []
    end

    test "includes the endpoint's api_key in llm_opts when set", %{scope: scope} do
      endpoint =
        endpoint_fixture(scope, %{"base_url" => "http://vllm:8000/v1", "api_key" => "secret-key"})

      add_model(scope, endpoint.id, "gpt-custom", nil)

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "custom:#{endpoint.id}:gpt-custom")

      assert llm_opts[:api_key] == "secret-key"
    end

    test "omits api_key from llm_opts when the endpoint has no key", %{scope: scope} do
      endpoint = endpoint_fixture(scope)
      add_model(scope, endpoint.id, "gpt-custom", nil)

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "custom:#{endpoint.id}:gpt-custom")

      refute Keyword.has_key?(llm_opts, :api_key)
    end

    test "returns :unknown_model for another user's endpoint", %{scope: scope} do
      other_scope = %Scope{user: user_fixture()}
      endpoint = endpoint_fixture(other_scope)
      add_model(other_scope, endpoint.id, "gpt-custom", nil)

      assert {:error, :unknown_model} =
               Providers.prepare_llm_args(scope, "custom:#{endpoint.id}:gpt-custom")
    end

    test "returns :unknown_model for an unknown model_id on an owned endpoint", %{scope: scope} do
      endpoint = endpoint_fixture(scope)
      add_model(scope, endpoint.id, "gpt-custom", nil)

      assert {:error, :unknown_model} =
               Providers.prepare_llm_args(scope, "custom:#{endpoint.id}:other-model")
    end
  end

  describe "model_from_client_params/1" do
    test "passes through 'custom' provider with a value of 'custom:<id>:<model>'" do
      assert {:ok, "custom:abc-123:gpt-x"} =
               Providers.model_from_client_params(%{
                 "provider" => "custom",
                 "value" => "custom:abc-123:gpt-x"
               })
    end

    test "rejects 'custom' provider values that are not custom:<id>:<model>" do
      assert :error =
               Providers.model_from_client_params(%{
                 "provider" => "custom",
                 "value" => "not-a-custom-value"
               })
    end

    test "preserves the existing behavior for non-custom providers" do
      assert {:ok, "anthropic:claude-sonnet-5"} =
               Providers.model_from_client_params(%{
                 "provider" => "anthropic",
                 "value" => "claude-sonnet-5"
               })
    end
  end

  defp endpoint_fixture(scope, attrs \\ %{}) do
    {:ok, endpoint} =
      CustomLlmEndpoints.create_endpoint(
        scope,
        Map.merge(%{"name" => "vLLM", "base_url" => "http://localhost:8000/v1"}, attrs)
      )

    endpoint
  end

  defp add_model(scope, endpoint_id, model_id, position) do
    attrs = %{"model_id" => model_id}
    attrs = if position, do: Map.put(attrs, "position", position), else: attrs

    {:ok, _model} = CustomLlmEndpoints.add_model(scope, endpoint_id, attrs)
    :ok
  end

  defp find_group(groups, endpoint_id) do
    Enum.find(groups, &(&1.id == "custom:#{endpoint_id}"))
  end
end
