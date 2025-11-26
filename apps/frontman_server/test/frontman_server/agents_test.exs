defmodule FrontmanServer.AgentsTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents
  alias FrontmanServer.Tasks

  @pubsub FrontmanServer.PubSub

  describe "broadcast_token/4" do
    test "broadcasts token to task topic" do
      task_id = "test_task_#{System.unique_integer([:positive])}"
      agent_id = "agent_123"

      Tasks.subscribe(@pubsub, task_id)

      Agents.broadcast_token(@pubsub, task_id, agent_id, "hello")

      assert_receive {:stream_token, ^agent_id, "hello"}, 100
    end
  end

  describe "broadcast_completed/3" do
    test "broadcasts completion to task topic" do
      task_id = "test_task_#{System.unique_integer([:positive])}"
      agent_id = "agent_123"

      Tasks.subscribe(@pubsub, task_id)

      Agents.broadcast_completed(@pubsub, task_id, agent_id)

      assert_receive {:agent_completed, ^agent_id}, 100
    end
  end

  describe "broadcast_error/4" do
    test "broadcasts error to task topic" do
      task_id = "test_task_#{System.unique_integer([:positive])}"
      agent_id = "agent_123"

      Tasks.subscribe(@pubsub, task_id)

      Agents.broadcast_error(@pubsub, task_id, agent_id, "something went wrong")

      assert_receive {:agent_error, ^agent_id, "something went wrong"}, 100
    end
  end
end
