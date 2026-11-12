defmodule FrontmanServer.Providers.PrepareApiKeyRuntimeCatalogTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    user = user_fixture()
    scope = %Scope{user: user}
    {:ok, scope: scope}
  end

  test "reads runtime catalog and separates group, credential, and transport", %{scope: scope} do
    original_providers = Application.fetch_env!(:frontman_server, :providers)
    on_exit(fn -> Application.put_env(:frontman_server, :providers, original_providers) end)

    Application.put_env(:frontman_server, :providers,
      self_hosted: %{
        display_name: "Self-hosted",
        credential_source: "anthropic",
        models: [
          {"Qwen3 Coder", "qwen3-coder",
           %LLMDB.Model{
             provider: :openai,
             id: "qwen3-coder",
             base_url: "http://vllm:8000/v1"
           }}
        ]
      }
    )

    :ok = Providers.upsert_api_key(scope, "anthropic", "runtime-key")
    assert %{groups: [%{id: "self_hosted"}]} = Providers.available_models(scope)

    assert {:ok, {%LLMDB.Model{} = resolved_model, llm_opts}} =
             Providers.resolve_model_access(scope, "self_hosted:qwen3-coder")

    assert resolved_model.provider == :openai
    assert resolved_model.id == "qwen3-coder"
    assert resolved_model.base_url == "http://vllm:8000/v1"
    assert llm_opts[:api_key] == "runtime-key"
    refute llm_opts[:anthropic_prompt_cache]

    assert {:error, :unknown_model} =
             Providers.resolve_model_access(scope, "future_provider:missing")
  end
end
