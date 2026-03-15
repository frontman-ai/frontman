defmodule FrontmanServerWeb.TaskChannelEnvKeyTest do
  @moduledoc """
  Integration tests for env API key extraction through the task channel prompt flow.
  """
  use FrontmanServerWeb.ChannelCase, async: true

  import FrontmanServer.ProvidersFixtures

  alias FrontmanServer.Tasks

  setup %{scope: scope} do
    {socket, _task_id} = join_task_channel(scope)
    complete_mcp_handshake(socket)
    {:ok, socket: socket}
  end

  defp push_prompt_and_assert_accepted(socket, metadata \\ %{}) do
    push(socket, "acp:message", prompt_request(metadata: metadata))
    :sys.get_state(socket.channel_pid)

    assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
    assert Process.alive?(socket.channel_pid)
  end

  describe "env key extraction through channel" do
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
end
