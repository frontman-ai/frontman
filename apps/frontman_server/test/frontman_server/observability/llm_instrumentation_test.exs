defmodule FrontmanServer.Observability.LLMInstrumentationTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Observability.LLMInstrumentation

  describe "parse_model/1" do
    test "extracts provider and model name from prefixed model" do
      assert {"anthropic", "claude-sonnet-4"} =
               LLMInstrumentation.parse_model("anthropic:claude-sonnet-4")
    end

    test "extracts provider and model name with version" do
      assert {"openai", "gpt-4-turbo-preview"} =
               LLMInstrumentation.parse_model("openai:gpt-4-turbo-preview")
    end

    test "handles model without provider prefix" do
      assert {"unknown", "gpt-4"} = LLMInstrumentation.parse_model("gpt-4")
    end

    test "handles model with multiple colons" do
      assert {"google", "gemini-pro:latest"} =
               LLMInstrumentation.parse_model("google:gemini-pro:latest")
    end
  end

  describe "with_llm_span/4" do
    test "executes callback and returns result" do
      result =
        LLMInstrumentation.with_llm_span(
          "anthropic:claude-sonnet-4",
          [%{role: :user, content: "Hello"}],
          [],
          fn -> {:ok, "response"} end
        )

      assert {:ok, "response"} = result
    end

    test "passes through errors from callback" do
      result =
        LLMInstrumentation.with_llm_span(
          "anthropic:claude-sonnet-4",
          [],
          [],
          fn -> {:error, :timeout} end
        )

      assert {:error, :timeout} = result
    end

    test "handles callback that raises" do
      assert_raise RuntimeError, "boom", fn ->
        LLMInstrumentation.with_llm_span(
          "anthropic:claude-sonnet-4",
          [],
          [],
          fn -> raise "boom" end
        )
      end
    end
  end

  describe "with_tool_span/3" do
    test "executes callback and returns result" do
      result =
        LLMInstrumentation.with_tool_span(
          "get_weather",
          "call_123",
          fn -> {:ok, %{temperature: 72}} end
        )

      assert {:ok, %{temperature: 72}} = result
    end

    test "handles error results" do
      result =
        LLMInstrumentation.with_tool_span(
          "get_weather",
          "call_123",
          fn -> {:error, "City not found"} end
        )

      assert {:error, "City not found"} = result
    end
  end

  describe "record_usage/1" do
    test "handles valid usage data" do
      usage = %{
        tokens: %{input: 100, output: 50},
        cost: 0.005
      }

      assert :ok = LLMInstrumentation.record_usage(usage)
    end

    test "handles missing cost" do
      usage = %{tokens: %{input: 100, output: 50}}

      assert :ok = LLMInstrumentation.record_usage(usage)
    end

    test "handles invalid input" do
      assert :ok = LLMInstrumentation.record_usage(%{})
      assert :ok = LLMInstrumentation.record_usage(nil)
    end
  end

  describe "record_output/2" do
    test "records output with no tool calls" do
      assert :ok = LLMInstrumentation.record_output("Hello!", [])
    end

    test "records output with tool calls" do
      tool_calls = [
        %{id: "call_1", tool_name: "test", arguments: %{}}
      ]

      assert :ok = LLMInstrumentation.record_output("", tool_calls)
    end
  end

  describe "record_response_id/1" do
    test "handles nil response id" do
      assert :ok = LLMInstrumentation.record_response_id(nil)
    end

    test "records valid response id" do
      assert :ok = LLMInstrumentation.record_response_id("msg_01XF123")
    end
  end

  describe "record_error/1" do
    test "records error" do
      assert :ok = LLMInstrumentation.record_error(:timeout)
    end

    test "handles exception" do
      error = %RuntimeError{message: "something went wrong"}
      assert :ok = LLMInstrumentation.record_error(error)
    end
  end
end
