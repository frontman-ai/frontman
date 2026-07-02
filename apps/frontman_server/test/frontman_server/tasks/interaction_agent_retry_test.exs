defmodule FrontmanServer.Tasks.InteractionAgentRetryTest do
  use ExUnit.Case, async: true

  import FrontmanServer.InteractionCase.Helpers, only: [agent_error: 2, agent_error: 4]

  alias FrontmanServer.Tasks.Interaction

  describe "AgentError fields" do
    test "struct sets retryable and category" do
      err = agent_error("Rate limited", "failed", true, "rate_limit")

      assert err.retryable == true
      assert err.category == "rate_limit"
      assert err.error == "Rate limited"
    end

    test "schema defaults retryable=false, category=unknown" do
      err = agent_error("Something went wrong", "failed")
      assert err.retryable == false
      assert err.category == "unknown"
    end

    test "Jason.Encoder includes retryable and category" do
      err = agent_error("Rate limited", "failed", true, "rate_limit")

      encoded = Jason.encode!(err)
      decoded = Jason.decode!(encoded)
      assert decoded["retryable"] == true
      assert decoded["category"] == "rate_limit"
      refute Map.has_key?(decoded, "type")
    end
  end

  describe "AgentRetry" do
    test "struct creates with retried_error_id" do
      retry = agent_retry("error-123")
      assert retry.retried_error_id == "error-123"
      assert is_binary(retry.id)
      assert %DateTime{} = retry.timestamp
    end

    test "Jason.Encoder includes retried_error_id" do
      retry = agent_retry("error-123")
      decoded = Jason.decode!(Jason.encode!(retry))
      refute Map.has_key?(decoded, "type")
      assert decoded["retried_error_id"] == "error-123"
    end
  end

  defp agent_retry(retried_error_id) do
    %Interaction.AgentRetry{
      id: Ecto.UUID.generate(),
      timestamp: Interaction.now(),
      retried_error_id: retried_error_id
    }
  end
end
