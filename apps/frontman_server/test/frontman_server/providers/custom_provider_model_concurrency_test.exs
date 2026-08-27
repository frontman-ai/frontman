# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomProviderModelConcurrencyTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Repo

  test "concurrent duplicate inserts create one model" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = Scope.for_user(user_fixture())

      try do
        {:ok, provider} =
          Providers.create_custom_provider(scope, %{
            name: "concurrent-provider",
            base_url: "https://93.184.216.34/v1"
          })

        parent = self()

        tasks =
          for _ <- 1..2 do
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                send(parent, :ready)

                receive do
                  :insert ->
                    Providers.add_custom_provider_model(scope, provider.id, %{
                      model_id: "llama-4-scout"
                    })
                end
              end)
            end)
          end

        assert_receive :ready
        assert_receive :ready
        Enum.each(tasks, &send(&1.pid, :insert))

        results = Enum.map(tasks, &Task.await/1)

        assert 1 == Enum.count(results, &match?({:ok, _model}, &1))
        assert 1 == Enum.count(results, &match?({:error, %{model_id: [_ | _]}}, &1))
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end
end
