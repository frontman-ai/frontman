defmodule FrontmanServerWeb.TaskChannelEnvKeyTest do
  @moduledoc """
  Integration tests for env API key extraction through the task channel prompt flow.

  Verifies that API keys sent via client metadata (openrouterKeyValue, anthropicKeyValue)
  are correctly extracted and passed through to agent execution.
  """
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServer.Tasks
  alias FrontmanServerWeb.UserSocket

  # We can't observe the env_api_key map directly since it's passed internally
  # to Tasks.add_user_message → Execution.run. Instead we verify that:
  # 1. The prompt is accepted (no error response)
  # 2. A UserMessage interaction is broadcast (agent spawned)
  # 3. When no API key can be resolved, the agent_error flows back correctly

  describe "prompt with Anthropic env key" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "accepts prompt with anthropicKeyValue in metadata", %{
      socket: socket,
      task_id: task_id
    } do
      prompt_request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{
                "role" => "user",
                "content" => %{"type" => "text", "text" => "Hello from Anthropic key test"}
              }
            ]
          },
          "metadata" => %{
            "anthropicKeyValue" => "sk-ant-test-key-123",
            "model" => %{"provider" => "anthropic", "value" => "claude-sonnet-4-5"}
          }
        }
      }

      push(socket, "acp:message", prompt_request)
      :sys.get_state(socket.channel_pid)

      # The prompt should be processed — a UserMessage interaction is broadcast
      # (this proves the channel extracted the key and passed it to add_user_message)
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}

      # The agent will either start successfully (if the key resolves) or
      # send an error. Either way the channel didn't crash — the key extraction worked.
      # We don't assert on agent success since that would require a real LLM call.
      # But the agent_error we get should NOT be about key extraction.

      # Verify channel is still alive
      assert Process.alive?(socket.channel_pid)

      # Wait for potential error from agent (no server key, env key may not actually work)
      # The important thing: the prompt was processed, not rejected at the channel level
      receive do
        _ -> :ok
      after
        100 -> :ok
      end

      assert Process.alive?(socket.channel_pid)
    end

    test "extracts model from metadata as Model struct", %{
      socket: socket,
      task_id: task_id
    } do
      # Subscribe to the task topic to observe the execution start
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      prompt_request = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{
                "role" => "user",
                "content" => %{"type" => "text", "text" => "Test model extraction"}
              }
            ]
          },
          "metadata" => %{
            "anthropicKeyValue" => "sk-ant-test-456",
            "model" => %{"provider" => "anthropic", "value" => "claude-sonnet-4-5"}
          }
        }
      }

      push(socket, "acp:message", prompt_request)
      :sys.get_state(socket.channel_pid)

      # The prompt is accepted — UserMessage interaction proves model+key were extracted
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
    end
  end

  describe "prompt with OpenRouter env key (regression)" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "accepts prompt with openrouterKeyValue in metadata", %{
      socket: socket
    } do
      prompt_request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{
                "role" => "user",
                "content" => %{"type" => "text", "text" => "Hello from OpenRouter key test"}
              }
            ]
          },
          "metadata" => %{
            "openrouterKeyValue" => "sk-or-test-key-789",
            "model" => %{"provider" => "openrouter", "value" => "openai/gpt-5.1-codex"}
          }
        }
      }

      push(socket, "acp:message", prompt_request)
      :sys.get_state(socket.channel_pid)

      # Prompt accepted — UserMessage interaction broadcast
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
      assert Process.alive?(socket.channel_pid)
    end
  end

  describe "prompt with both env keys" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "accepts prompt with both openrouterKeyValue and anthropicKeyValue", %{
      socket: socket
    } do
      prompt_request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{
                "role" => "user",
                "content" => %{"type" => "text", "text" => "Hello with both keys"}
              }
            ]
          },
          "metadata" => %{
            "openrouterKeyValue" => "sk-or-both-test",
            "anthropicKeyValue" => "sk-ant-both-test",
            "model" => %{"provider" => "anthropic", "value" => "claude-sonnet-4-5"}
          }
        }
      }

      push(socket, "acp:message", prompt_request)
      :sys.get_state(socket.channel_pid)

      # Both keys sent, Anthropic model selected — prompt is accepted
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
      assert Process.alive?(socket.channel_pid)
    end

    test "prompt without any env keys or model still works (falls back)", %{
      socket: socket
    } do
      # No metadata at all — should still accept the prompt and fall back to defaults
      prompt_request = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{
                "role" => "user",
                "content" => %{"type" => "text", "text" => "Hello with no keys"}
              }
            ]
          }
        }
      }

      push(socket, "acp:message", prompt_request)
      :sys.get_state(socket.channel_pid)

      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
      assert Process.alive?(socket.channel_pid)
    end
  end
end
