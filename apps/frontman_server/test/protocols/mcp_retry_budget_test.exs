defmodule FrontmanServer.Protocols.MCP.RetryBudgetTest do
  use ExUnit.Case, async: true
  alias FrontmanServer.Protocols.MCP.RetryBudget

  test "configuration requires positive finite integer limits" do
    for value <- [0, -1, 1.5, nil, :infinity] do
      assert {:error, :invalid_budget} = RetryBudget.new(value, 100)
      assert {:error, :invalid_budget} = RetryBudget.new(2, value)
    end
  end

  test "initial attempt counts and the deadline is exclusive" do
    assert {:ok, budget} = RetryBudget.new(2, 100)
    assert {:ok, retry} = RetryBudget.advance(budget, 99)
    assert {:error, :retry_exhausted} = RetryBudget.advance(retry, 99)
    assert {:error, :retry_exhausted} = RetryBudget.advance(budget, 100)
    assert {:ok, initial_only} = RetryBudget.new(1, 100)
    assert {:error, :retry_exhausted} = RetryBudget.advance(initial_only, 0)
  end

  test "budgets are independent and elapsed time cannot move backwards" do
    assert {:ok, first} = RetryBudget.new(4, 100)
    assert {:ok, second} = RetryBudget.new(2, 200)
    assert {:ok, advanced} = RetryBudget.advance(first, 50)
    assert {:error, :invalid_elapsed} = RetryBudget.advance(advanced, 49)
    assert {:error, :invalid_elapsed} = RetryBudget.advance(first, -1)
    assert {:ok, _independent} = RetryBudget.advance(second, 150)
    assert {:ok, _unchanged} = RetryBudget.advance(first, 0)
  end
end
