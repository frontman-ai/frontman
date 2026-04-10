defmodule FrontmanServerWeb.TaskChannelEnvKeyTest do
  @moduledoc """
  Integration tests for env API key extraction through the task channel prompt flow.
  """
  use FrontmanServerWeb.ChannelCase, async: true

  import FrontmanServer.ProvidersFixtures

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.ExecutionEvent

  defp push_prompt_and_assert_accepted(socket, meta \\ %{}) do
    push(socket, "acp:message", prompt_request(_meta: meta))
    :sys.get_state(socket.channel_pid)

    assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
    assert Process.alive?(socket.channel_pid)
  end

  describe "env key extraction through channel" do
    setup %{scope: scope} do
      {socket, _task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket}
    end

    test "accepts prompt with anthropicKeyValue", %{socket: socket} do
      push_prompt_and_assert_accepted(socket, %{
        "anthropicKeyValue" => "sk-ant-test-key-123",
        "model" => %{"provider" => "anthropic", "value" => "claude-sonnet-4-5"}
      })
    end

    test "accepts prompt with openrouterKeyValue (regression)", %{socket: socket} do
      push_prompt_and_assert_accepted(socket, %{
        "openrouterKeyValue" => "sk-or-test-key-789",
        "model" => %{"provider" => "openrouter", "value" => "openai/gpt-5.1-codex"}
      })
    end

    test "accepts prompt with both env keys", %{socket: socket} do
      push_prompt_and_assert_accepted(socket, %{
        "openrouterKeyValue" => "sk-or-both-test",
        "anthropicKeyValue" => "sk-ant-both-test",
        "model" => %{"provider" => "anthropic", "value" => "claude-sonnet-4-5"}
      })
    end

    test "falls back when no env keys or model provided", %{socket: socket} do
      push_prompt_and_assert_accepted(socket)
    end
  end

  describe "env key persistence across retries" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "env key in prompt _meta is still on scope when :fire_retry fires", %{
      socket: socket
    } do
      push_prompt_and_assert_accepted(socket, %{"anthropicKeyValue" => "sk-ant-retry-test"})

      # Confirm the enriched scope was persisted to socket assigns after the prompt
      %{assigns: %{scope: scope_after_prompt}} = :sys.get_state(socket.channel_pid)
      assert scope_after_prompt.env_api_keys["anthropic"] == "sk-ant-retry-test"

      # Trigger a transient error so the retry coordinator starts.
      # We send directly to the channel pid (not via PubSub) to avoid
      # interference from concurrent sockets under CI load.
      error = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}

      event = %ExecutionEvent{
        type: :failed,
        payload: {:error, error, System.unique_integer([:positive])}
      }

      send(socket.channel_pid, {:execution_event, event})

      :sys.get_state(socket.channel_pid)

      # Fire the retry — this reads scope from socket.assigns.scope
      send(socket.channel_pid, :fire_retry)
      :sys.get_state(socket.channel_pid)

      # The scope on the socket must still carry the env key after the retry fires
      %{assigns: %{scope: scope_after_retry}} = :sys.get_state(socket.channel_pid)
      assert scope_after_retry.env_api_keys["anthropic"] == "sk-ant-retry-test"
    end
  end
end
