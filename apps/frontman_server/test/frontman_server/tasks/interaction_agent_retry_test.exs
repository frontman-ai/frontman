defmodule FrontmanServer.Tasks.InteractionAgentRetryTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Interaction

  describe "AgentError build fields" do
    test "build/4 sets retryable and category" do
      err = Interaction.AgentError.build("Rate limited", "failed", true, "rate_limit")

      assert err.retryable == true
      assert err.category == "rate_limit"
      assert err.error == "Rate limited"
    end

    test "build/2 defaults retryable=false, category=unknown" do
      err = Interaction.AgentError.build("Something went wrong", "failed")
      assert err.retryable == false
      assert err.category == "unknown"
    end

    test "Jason.Encoder includes retryable and category" do
      err = Interaction.AgentError.build("Rate limited", "failed", true, "rate_limit")

      encoded = Jason.encode!(err)
      decoded = Jason.decode!(encoded)
      assert decoded["retryable"] == true
      assert decoded["category"] == "rate_limit"
      assert decoded["type"] == "agent_error"
    end
  end

  describe "AgentRetry" do
    test "build/1 creates with retried_error_id" do
      retry = Interaction.AgentRetry.build("error-123")
      assert retry.retried_error_id == "error-123"
      assert is_binary(retry.id)
      assert %DateTime{} = retry.timestamp
    end

    test "Jason.Encoder includes type and retried_error_id" do
      retry = Interaction.AgentRetry.build("error-123")
      decoded = Jason.decode!(Jason.encode!(retry))
      assert decoded["type"] == "agent_retry"
      assert decoded["retried_error_id"] == "error-123"
    end
  end
end
