defmodule FrontmanServer.TasksTest do
  use ExUnit.Case, async: false
  use FrontmanServer.CassetteCase

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction

  describe "create_task with agent orchestration" do
    test "automatically spawns an agent", %{fixture_path: fixture_path} do
      task_id = "test_task_#{System.unique_integer([:positive])}"

      {:ok, ^task_id} =
        Tasks.create_task(%{message: "Hello", task_id: task_id}, %{fixture_path: fixture_path})

      assert :ok = wait_for_agent_completion(task_id)

      interactions = Tasks.get_interactions(task_id)

      assert Enum.any?(interactions, fn
               %Interaction.AgentSpawned{} -> true
               _ -> false
             end)
    end

    test "records UserMessage, AgentSpawned, AgentResponse, and AgentCompleted interactions", %{
      fixture_path: fixture_path
    } do
      task_id = "test_task_#{System.unique_integer([:positive])}"

      {:ok, ^task_id} =
        Tasks.create_task(%{message: "Test message", task_id: task_id}, %{
          fixture_path: fixture_path
        })

      assert :ok = wait_for_agent_completion(task_id)

      interactions = Tasks.get_interactions(task_id)

      types =
        Enum.map(interactions, fn
          %Interaction.UserMessage{} -> :user_message
          %Interaction.AgentSpawned{} -> :agent_spawned
          %Interaction.AgentResponse{} -> :agent_response
          %Interaction.AgentCompleted{} -> :agent_completed
        end)

      assert :user_message in types
      assert :agent_spawned in types
      assert :agent_response in types
      assert :agent_completed in types

      assert Enum.at(interactions, 0).__struct__ == Interaction.UserMessage
      assert Enum.at(interactions, 1).__struct__ == Interaction.AgentSpawned
      assert Enum.at(interactions, -2).__struct__ == Interaction.AgentResponse
      assert Enum.at(interactions, -1).__struct__ == Interaction.AgentCompleted
    end

    test "agent writes response to correct task", %{fixture_path: fixture_path} do
      task_id = "test_task_#{System.unique_integer([:positive])}"

      {:ok, ^task_id} =
        Tasks.create_task(%{message: "Write a haiku", task_id: task_id}, %{
          fixture_path: fixture_path
        })

      assert :ok = wait_for_agent_completion(task_id)

      interactions = Tasks.get_interactions(task_id)

      agent_response =
        Enum.find(interactions, fn
          %Interaction.AgentResponse{} -> true
          _ -> false
        end)

      assert agent_response != nil
      assert agent_response.content != ""
      assert is_binary(agent_response.content)
    end

    test "agent completes and stops after one iteration", %{fixture_path: fixture_path} do
      task_id = "test_task_#{System.unique_integer([:positive])}"

      {:ok, ^task_id} =
        Tasks.create_task(%{message: "Hello", task_id: task_id}, %{fixture_path: fixture_path})

      assert :ok = wait_for_agent_completion(task_id)

      interactions = Tasks.get_interactions(task_id)

      completed_count =
        Enum.count(interactions, fn
          %Interaction.AgentCompleted{} -> true
          _ -> false
        end)

      assert completed_count == 1
    end
  end
end
