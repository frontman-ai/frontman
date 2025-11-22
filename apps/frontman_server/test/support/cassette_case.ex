defmodule FrontmanServer.CassetteCase do
  @moduledoc """
  Test helpers for using ReqLLM fixtures with LLM API calls.

  This module provides automatic fixture path management via ExUnit setup,
  making tests faster and independent of external APIs.

  ## Recording vs Replaying

  Set the environment variable to control mode:
  - `REQ_LLM_FIXTURES_MODE=record mix test` - Record new fixtures (makes real API calls)
  - `mix test` - Replay from existing fixtures (default)

  ## Usage

      use FrontmanServer.CassetteCase

      test "creates task with LLM response", %{fixture_path: fixture_path} do
        {:ok, task_id} = Tasks.create_task(
          %{message: "Hello", task_id: "test_123"},
          %{fixture_path: fixture_path}
        )
        # Assertions...
      end

  By default, the fixture name is derived from the test name. You can override it with a tag:

      @tag fixture_name: "custom_name"
      test "my test", %{fixture_path: fixture_path} do
        # Uses "custom_name.json" instead of "my_test.json"
      end
  """

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks

  def wait_for_agent_completion(task_id, timeout \\ 10_000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    wait_loop = fn wait_loop ->
      interactions = Tasks.get_interactions(task_id)

      has_completed =
        Enum.any?(interactions, fn
          %Interaction.AgentCompleted{} -> true
          _ -> false
        end)

      cond do
        has_completed ->
          :ok

        System.monotonic_time(:millisecond) > deadline ->
          {:error, :timeout}

        true ->
          Process.sleep(50)
          wait_loop.(wait_loop)
      end
    end

    wait_loop.(wait_loop)
  end

  defmacro __using__(_opts) do
    quote do
      import FrontmanServer.CassetteCase

      setup context do
        # Skip fixture setup if :skip_cassette tag is present
        if context[:skip_cassette] do
          {:ok, []}
        else
          fixture_dir =
            Application.get_env(:frontman_server, :llm_fixtures_path, "test/fixtures/llm")

          File.mkdir_p!(fixture_dir)

          # Use custom fixture name from tag if provided, otherwise derive from test name
          fixture_name =
            case context do
              %{fixture_name: name} -> name
              %{test: test_name} -> test_name |> Atom.to_string() |> sanitize_fixture_name()
              _ -> raise "Cannot determine fixture name from context"
            end

          fixture_path = Path.join(fixture_dir, "#{fixture_name}.json")

          {:ok, fixture_path: fixture_path}
        end
      end

      defp sanitize_fixture_name(name) do
        name
        |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
        |> String.replace(~r/_+/, "_")
        |> String.trim("_")
      end
    end
  end
end
