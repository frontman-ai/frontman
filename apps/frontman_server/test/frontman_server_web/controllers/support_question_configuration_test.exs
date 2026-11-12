defmodule FrontmanServerWeb.SupportQuestionConfigurationTest do
  use FrontmanServerWeb.ConnCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Workers.SendAgentFeedbackToDiscord
  alias FrontmanServer.Workers.SendSupportQuestionToDiscord

  test "missing or empty shared webhook rejects before enqueueing", %{conn: conn} do
    original = Application.fetch_env!(:frontman_server, SendAgentFeedbackToDiscord)
    on_exit(fn -> Application.put_env(:frontman_server, SendAgentFeedbackToDiscord, original) end)

    for config <- [[webhook_url: nil], [webhook_url: ""]] do
      Application.put_env(:frontman_server, SendAgentFeedbackToDiscord, config)

      response =
        conn
        |> recycle()
        |> put_req_header("content-type", "application/json")
        |> post("/api/support/questions", Jason.encode!(%{"question" => "Help?"}))
        |> json_response(503)

      assert response == %{"status" => "unavailable", "submitted" => false}
    end

    refute_enqueued(worker: SendSupportQuestionToDiscord)
  end
end
