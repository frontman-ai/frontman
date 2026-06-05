defmodule FrontmanServerWeb.TaskChannelEnvKeyTest do
  @moduledoc """
  Integration tests for env API key extraction through the task channel prompt flow.
  """
  use FrontmanServerWeb.ChannelCase, async: true

  import FrontmanServer.ProvidersFixtures

  alias FrontmanServer.Tasks

  defp push_prompt_and_assert_accepted(socket, meta \\ %{}) do
    push(socket, "acp:message", prompt_request(_meta: meta))
    :sys.get_state(socket.channel_pid)

    assert_receive {:interaction, %Tasks.Interaction.UserMessage{}, _turn_number}
    refute_push("acp:message", %{"error" => %{"code" => -32_000}})
    assert Process.alive?(socket.channel_pid)
    wait_for_execution_idle(socket)
  end

  defp wait_for_execution_idle(socket, attempts \\ 20) do
    %{assigns: %{task_id: task_id}} = :sys.get_state(socket.channel_pid)

    case SwarmAi.running?(FrontmanServer.AgentRuntime, task_id) do
      false ->
        :ok

      true when attempts > 0 ->
        Process.sleep(25)
        wait_for_execution_idle(socket, attempts - 1)
    end
  end

  describe "env key extraction through channel" do
    setup %{scope: scope} do
      {socket, _task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket}
    end

    for {meta_key, provider, model} <- [
          {"anthropicKeyValue", "anthropic", "claude-sonnet-4-5"},
          {"openrouterKeyValue", "openrouter", "openai/gpt-5.5"},
          {"fireworksKeyValue", "fireworks", "accounts/fireworks/routers/kimi-k2p5-turbo"}
        ] do
      test "accepts prompt with #{meta_key}", %{socket: socket} do
        push_prompt_and_assert_accepted(socket, %{
          unquote(meta_key) => "sk-#{unquote(provider)}-test",
          "model" => %{"provider" => unquote(provider), "value" => unquote(model)}
        })
      end
    end

    test "accepts prompt with multiple env keys", %{socket: socket} do
      push_prompt_and_assert_accepted(socket, %{
        "openrouterKeyValue" => "sk-or-multiple-test",
        "anthropicKeyValue" => "sk-ant-multiple-test",
        "model" => %{"provider" => "anthropic", "value" => "claude-sonnet-4-5"}
      })
    end

    test "falls back when no env keys or model provided", %{socket: socket} do
      push_prompt_and_assert_accepted(socket)

      %{assigns: %{scope: scope_after_prompt}} = :sys.get_state(socket.channel_pid)
      assert scope_after_prompt.env_api_keys == %{}
    end
  end
end
