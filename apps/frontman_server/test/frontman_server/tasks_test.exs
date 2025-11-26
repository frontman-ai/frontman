defmodule FrontmanServer.TasksTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.Tasks

  describe "topic/1" do
    test "returns topic string for task_id" do
      assert Tasks.topic("abc123") == "task:abc123"
    end
  end

  describe "subscribe/2" do
    test "subscribes calling process to task topic" do
      task_id = "test_sub_#{System.unique_integer([:positive])}"

      :ok = Tasks.subscribe(FrontmanServer.PubSub, task_id)

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), {:test_event, "hello"})

      assert_receive {:test_event, "hello"}, 100
    end
  end
end
