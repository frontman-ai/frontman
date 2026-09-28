defmodule FrontmanServer.Billing.E2ESeedsTest do
  use FrontmanServer.DataCase, async: false

  import ExUnit.CaptureIO

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.{Customer, Subscription}

  test "repeated E2E setup grants subscription access without Stripe credentials" do
    variables = ~w(E2E_OPENAI_ACCESS_TOKEN E2E_OPENAI_REFRESH_TOKEN E2E_OPENAI_ACCOUNT_ID)
    previous = Map.new(variables, &{&1, System.get_env(&1)})
    Enum.each(variables, &System.delete_env/1)
    on_exit(fn -> System.put_env(previous) end)

    capture_io(fn ->
      Code.eval_file("priv/repo/e2e_seeds.exs")
      Code.eval_file("priv/repo/e2e_seeds.exs")
    end)

    user = Accounts.get_user_by_email("e2e@frontman.local")
    scope = Scope.for_user(user)

    assert Billing.allow_access?(scope)
    assert Repo.aggregate(Customer.for_user(user.id), :count) == 1
    assert Repo.aggregate(Subscription.for_user(user.id), :count) == 1
  end
end
