defmodule FrontmanServer.Tasks.TitleGeneratorIntegrationTest do
  @moduledoc """
  Integration test verifying that TitleGenerator resolves the user's
  selected model and env key through the standard `prepare_api_key` chain.
  """
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.AccountsFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{Model, ResolvedKey}

  setup do
    user = user_fixture()
    {:ok, scope: %Scope{user: user}}
  end

  describe "title generation key resolution" do
    test "uses user's selected model and env key", %{scope: scope} do
      env_api_key = %{"anthropic" => "sk-ant-title-test"}

      {:ok, model} = Model.parse("anthropic:claude-sonnet-4-5")
      model_string = Model.resolve_string(model)

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, model_string, env_api_key, skip_quota: true)

      assert resolved.provider == "anthropic"
      assert resolved.api_key == "sk-ant-title-test"
      assert resolved.model == "anthropic:claude-sonnet-4-5"
    end
  end
end
