defmodule FrontmanServer.Workers.SendSupportQuestionToDiscordTest do
  use FrontmanServer.DataCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Support
  alias FrontmanServer.Workers.SendSupportQuestionToDiscord, as: Worker

  setup do
    original = Application.fetch_env!(:frontman_server, Support)

    Application.put_env(:frontman_server, Support,
      enabled: true,
      webhook_url: "https://discord.test/support-secret",
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> Application.put_env(:frontman_server, Support, original) end)
    :ok
  end

  test "posts the full question with mentions disabled and an untrusted label" do
    question = "@everyone " <> String.duplicate("x", 3990)
    id = Ecto.UUID.generate()

    Req.Test.expect(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)
      assert payload["allowed_mentions"] == %{"parse" => []}
      [embed] = payload["embeds"]
      assert embed["description"] == question
      assert embed["title"] =~ "untrusted external input"
      assert embed["footer"]["text"] =~ id
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert :ok = perform_job(Worker, %{question: question, submission_id: id})
    assert {:ok, options} = Support.delivery_options()
    assert options[:retry] == false
    assert options[:redirect] == false
    assert options[:receive_timeout] == 5000
  end

  test "non-2xx errors contain neither question, response body nor webhook URL" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{message: "sensitive-response"})
    end)

    assert {:error, {:discord_status, 500}} =
             perform_job(Worker, %{
               question: "private-question",
               submission_id: Ecto.UUID.generate()
             })
  end

  test "transport failure returns a sanitized retryable error" do
    Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :timeout))

    assert {:error, :discord_request_failed} =
             perform_job(Worker, %{question: "Help?", submission_id: Ecto.UUID.generate()})
  end

  test "honors a bounded Discord retry delay without unlimited snoozes" do
    Req.Test.expect(__MODULE__, fn conn ->
      conn |> Plug.Conn.put_status(429) |> Req.Test.json(%{retry_after: 1.5})
    end)

    result = perform_job(Worker, %{question: "Help?", submission_id: Ecto.UUID.generate()})
    assert result == {:error, {:discord_rate_limited, 2}}
    error = Oban.PerformError.exception({Worker, result})
    assert Worker.backoff(%Oban.Job{unsaved_error: %{reason: error}}) == 2

    Req.Test.expect(__MODULE__, fn conn ->
      conn |> Plug.Conn.put_status(429) |> Req.Test.json(%{retry_after: 7200})
    end)

    assert {:error, {:discord_rate_limited, 3600}} =
             perform_job(Worker, %{question: "Help?", submission_id: Ecto.UUID.generate()})
  end

  test "disabled delivery cancels queued jobs rather than pretending they were sent" do
    Application.put_env(:frontman_server, Support, enabled: false)

    assert {:cancel, :unavailable} =
             perform_job(Worker, %{question: "Help?", submission_id: Ecto.UUID.generate()})
  end

  test "invalid persisted questions are cancelled before delivery" do
    assert {:cancel, :invalid_question} =
             perform_job(Worker, %{question: " ", submission_id: Ecto.UUID.generate()})
  end
end
