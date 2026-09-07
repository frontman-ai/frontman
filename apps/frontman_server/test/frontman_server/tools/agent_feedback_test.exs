defmodule FrontmanServer.Tools.AgentFeedbackTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.AgentFeedback
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Workers.SendAgentFeedbackToDiscord
  alias ModelContextProtocol, as: MCP

  test "enqueues feedback for Discord" do
    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope, framework: "nextjs").id
    {:ok, task} = Tasks.get_task_with_history(scope, task_id)

    result =
      AgentFeedback.execute(
        %{
          "outcome" => "feature_request",
          "message" => "Need better route context. The route tool did not explain dynamic params."
        },
        %Context{task: task}
      )

    refute MCP.error?(result)

    assert_enqueued(
      worker: SendAgentFeedbackToDiscord,
      args: %{
        task_id: task.id,
        framework: "nextjs",
        task_title: task.short_desc,
        outcome: "feature_request",
        message: "Need better route context. The route tool did not explain dynamic params."
      }
    )
  end

  test "rejects blank, invalid, and oversized messages without enqueueing" do
    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope, framework: "nextjs").id
    {:ok, task} = Tasks.get_task(scope, task_id)

    for message <- [
          nil,
          123,
          "",
          " \n\t",
          String.duplicate("a", 2001),
          String.duplicate("e\u0301", 1001)
        ] do
      result =
        AgentFeedback.execute(
          %{"outcome" => "stuck", "message" => message},
          %Context{task: task}
        )

      assert MCP.error?(result)
    end

    refute_enqueued(worker: SendAgentFeedbackToDiscord)
  end

  test "accepts a 2000-character message without truncation" do
    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope, framework: "nextjs").id
    {:ok, task} = Tasks.get_task(scope, task_id)
    message = String.duplicate("é", 2000)

    result =
      AgentFeedback.execute(
        %{"outcome" => "stuck", "message" => message},
        %Context{task: task}
      )

    refute MCP.error?(result)
    assert MCP.extract_content_text(result) == "Feedback sent"
    assert_enqueued(worker: SendAgentFeedbackToDiscord, args: %{message: message})
  end

  test "rejects invalid outcome" do
    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope, framework: "nextjs").id
    {:ok, task} = Tasks.get_task_with_history(scope, task_id)

    result = AgentFeedback.execute(%{"outcome" => "bad", "message" => "x"}, %Context{task: task})

    assert MCP.error?(result)
  end
end
