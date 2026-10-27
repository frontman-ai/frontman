defmodule FrontmanServer.Protocols.MCP.RetryPolicyTest do
  use ExUnit.Case, async: true
  alias FrontmanServer.Protocols.MCP.RetryPolicy

  test "retry requires explicit permission and finite caller-supplied budgets" do
    assert RetryPolicy.decide(:acknowledged_interim, :denied, 1, 3, 0, 30_000) ==
             {:stop, :retry_not_permitted}

    assert RetryPolicy.decide(:acknowledged_interim, :authorized, 1, 3, 0, 30_000) ==
             :request_continuation

    assert RetryPolicy.decide(:acknowledged_interim, :authorized, 3, 3, 0, 30_000) ==
             {:stop, :retry_exhausted}

    assert RetryPolicy.decide(:acknowledged_interim, :authorized, 2, 3, 30_000, 30_000) ==
             {:stop, :retry_exhausted}
  end

  test "cancellation and uncertain outcomes cannot authorize another dispatch" do
    for permission <- [:denied, :authorized] do
      assert RetryPolicy.decide(:cancelled, permission, 1, 3, 0, 30_000) ==
               {:stop, :cancelled}

      assert RetryPolicy.decide(:outcome_unknown, permission, 1, 3, 0, 30_000) ==
               {:stop, :outcome_unknown}
    end
  end

  test "unsupported inputs and protocol failures remain distinct" do
    for reason <- [:unsupported_input, :protocol_failure] do
      assert RetryPolicy.decide(reason, :authorized, 1, 3, 0, 30_000) == {:stop, reason}
    end
  end
end
