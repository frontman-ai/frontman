defmodule FrontmanServerWeb.TaskChannelTest do
  use FrontmanServerWeb.ChannelCase

  alias FrontmanServerWeb.{UserSocket, TaskChannel}

  test "join task:new creates new task and returns task_id" do
    {:ok, response, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(TaskChannel, "task:new", %{})

    assert response.task_id != nil
    assert socket.assigns.task_id == response.task_id

    # Should have agent_spawned interaction (task_id === agent_id)
    assert [%{type: "agent_spawned", agent_id: agent_id}] = response.interactions
    assert agent_id == response.task_id
  end

  test "send_message triggers full agent response flow" do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(TaskChannel, "task:new", %{})

    ref = push(socket, "send_message", %{"content" => "Hello"})
    assert_reply ref, :ok

    # User message interaction
    assert_push "interaction", %{type: "user_message", content: "Hello"}

    # Stream tokens (agent already exists, starts streaming)
    assert_push "stream_token", %{token: "Hello"}

    # Agent response interaction (after streaming completes)
    assert_push "interaction", %{type: "agent_response"}, 2000

    # Agent completed
    assert_push "agent_completed", %{}, 2000
  end
end
