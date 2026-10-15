defmodule FrontmanServer.Billing.RunAllowanceTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.{Billing, Repo}

  test "concurrent consumption on independent connections admits exactly five runs" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        results =
          Task.async_stream(
            1..12,
            fn _ ->
              Sandbox.unboxed_run(Repo, fn -> Billing.consume_pretrial_run(scope) end)
            end,
            max_concurrency: 12,
            timeout: 5_000
          )
          |> Enum.map(fn {:ok, result} -> result end)

        assert Enum.count(results, &(&1 == :ok)) == 5
        assert Enum.count(results, &(&1 == {:error, :billing_inactive})) == 7
        assert %{pretrial_runs_remaining: 0} = Billing.status(scope)
      after
        Repo.delete!(scope.user)
      end
    end)
  end
end
