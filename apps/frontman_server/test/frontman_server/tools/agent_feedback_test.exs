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

  test "rejects invalid outcome" do
    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope, framework: "nextjs").id
    {:ok, task} = Tasks.get_task_with_history(scope, task_id)

    result = AgentFeedback.execute(%{"outcome" => "bad", "message" => "x"}, %Context{task: task})

    assert MCP.error?(result)
  end
end
