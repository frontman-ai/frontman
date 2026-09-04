defmodule FrontmanServer.Workers.SendAgentFeedbackToDiscordTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Workers.SendAgentFeedbackToDiscord

  setup do
    original_config = Application.get_env(:frontman_server, SendAgentFeedbackToDiscord, [])

    Application.put_env(
      :frontman_server,
      SendAgentFeedbackToDiscord,
      Keyword.put(original_config, :req_options, plug: {Req.Test, :agent_feedback_webhook})
    )

    on_exit(fn ->
      Application.put_env(:frontman_server, SendAgentFeedbackToDiscord, original_config)
    end)

    :ok
  end

  test "posts agent feedback embed to the configured Discord webhook" do
    Req.Test.stub(:agent_feedback_webhook, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      [embed] = payload["embeds"]
      assert embed["title"] == "Agent Feedback"
      assert embed["color"] == 0xFEE75C

      fields = Map.new(embed["fields"], &{&1["name"], &1["value"]})
      assert fields["Outcome"] == "stuck"
      assert fields["Framework"] == "nextjs"
      assert fields["Task"] == "Fix checkout button"

      assert fields["Message"] ==
               "Could not inspect server actions. Missing server action context."

      assert fields["Task ID"] == "task-1"

      Req.Test.json(conn, %{ok: true})
    end)

    assert :ok =
             perform_job(SendAgentFeedbackToDiscord, %{
               task_id: "task-1",
               framework: "nextjs",
               task_title: "Fix checkout button",
               outcome: "stuck",
               message: "Could not inspect server actions. Missing server action context."
             })
  end

  test "returns error tuple on non-2xx response" do
    Req.Test.stub(:agent_feedback_webhook, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "rate limited"}))
    end)

    assert {:error, _reason} =
             perform_job(SendAgentFeedbackToDiscord, %{
               task_id: "task-1",
               outcome: "failed",
               message: "Failed"
             })
  end
end
