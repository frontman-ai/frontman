defmodule FrontmanServerWeb.SupportQuestionControllerTest do
  use FrontmanServerWeb.ConnCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  alias Ecto.Adapters.SQL
  alias FrontmanServer.Repo
  alias FrontmanServer.Workers.SendAgentFeedbackToDiscord
  alias FrontmanServer.Workers.SendSupportQuestionToDiscord

  setup do
    original = Application.fetch_env!(:frontman_server, SendAgentFeedbackToDiscord)

    Application.put_env(:frontman_server, SendAgentFeedbackToDiscord,
      webhook_url: "https://discord.test/support"
    )

    on_exit(fn -> Application.put_env(:frontman_server, SendAgentFeedbackToDiscord, original) end)
    :ok
  end

  test "accepts an anonymous question and queues only server-owned metadata", %{conn: conn} do
    conn = submit(conn, %{"question" => "Does Frontman work with Astro?"})
    response = json_response(conn, 202)

    assert %{"status" => "queued", "submitted" => true, "submission_id" => id} = response
    assert {:ok, ^id} = Ecto.UUID.cast(id)
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]

    [job] = all_enqueued(worker: SendSupportQuestionToDiscord)

    assert job.args == %{
             "question" => "Does Frontman work with Astro?",
             "submission_id" => id,
             "slot" => 0
           }

    assert job.max_attempts == 3
    assert job.queue == "support"
    assert Application.fetch_env!(:frontman_server, Oban)[:queues][:support] == 10
  end

  test "rejects missing, blank, non-string, extra and oversized input", %{conn: conn} do
    for input <- [
          %{},
          %{"question" => " \n "},
          %{"question" => 42},
          %{"question" => "Help", "webhook_url" => "https://example.com"},
          %{"question" => "Help", "slot" => 10},
          %{"question" => String.duplicate("x", 4001)},
          %{"question" => String.duplicate("😀", 2001)},
          [],
          nil
        ] do
      assert %{"error" => _} = conn |> recycle() |> submit(input) |> json_response(422)
    end

    refute_enqueued(worker: SendSupportQuestionToDiscord)
  end

  test "accepts exactly 4000 UTF-16 units without truncation", %{conn: conn} do
    question = String.duplicate("😀", 2000)

    assert %{"submitted" => true} =
             conn |> submit(%{"question" => question}) |> json_response(202)

    assert_enqueued(worker: SendSupportQuestionToDiscord, args: %{question: question})
  end

  test "does not use query parameters as the question", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/support/questions?question=Help", "{}")

    assert %{"error" => _} = json_response(conn, 422)
    refute_enqueued(worker: SendSupportQuestionToDiscord)
  end

  test "missing or empty shared webhook rejects before enqueueing", %{conn: conn} do
    for config <- [[webhook_url: nil], [webhook_url: ""]] do
      Application.put_env(:frontman_server, SendAgentFeedbackToDiscord, config)
      response = conn |> recycle() |> submit(%{"question" => "Help?"}) |> json_response(503)
      assert response == %{"status" => "unavailable", "submitted" => false}
    end

    refute_enqueued(worker: SendSupportQuestionToDiscord)
  end

  test "rejects invalid JSON, non-JSON content and bodies over 32 KiB", %{conn: conn} do
    for {content_type, body, status} <- [
          {"application/json", "{", 400},
          {"application/x-www-form-urlencoded", "question=Help", 415},
          {"text/plain", "Help", 415},
          {"application/json", Jason.encode!(%{question: String.duplicate("x", 32_768)}), 413}
        ] do
      response =
        conn
        |> recycle()
        |> put_req_header("content-type", content_type)
        |> post("/api/support/questions", body)

      assert %{"error" => _} = json_response(response, status)
      assert get_resp_header(response, "access-control-allow-origin") == ["*"]
    end

    refute_enqueued(worker: SendSupportQuestionToDiscord)
  end

  test "database failure reports an unknown result without exposing the question", %{conn: conn} do
    assert {:error, :expected} =
             Repo.transaction(fn ->
               assert {:error, %Postgrex.Error{}} =
                        SQL.query(Repo, "SELECT 1 / 0", [], log: false)

               conn = submit(conn, %{"question" => "private-question"})
               assert json_response(conn, 500) == %{"status" => "unknown", "submitted" => nil}
               Repo.rollback(:expected)
             end)
  end

  test "keeps support content out of request diagnostics", %{conn: conn} do
    question = "private-question-marker"

    log =
      ExUnit.CaptureLog.capture_log([level: :debug], fn ->
        conn = submit(conn, %{"question" => question})
        assert json_response(conn, 202)
        assert Sentry.PlugContext.build_request_interface_data(conn, []).data == %{}
      end)

    refute log =~ question
  end

  test "ten unfinished jobs occupy all slots regardless of state or age", %{conn: conn} do
    fill_slots(conn)
    jobs = all_enqueued(worker: SendSupportQuestionToDiscord)
    assert Enum.sort(Enum.map(jobs, & &1.args["slot"])) == Enum.to_list(0..9)
    assert jobs |> Enum.map(& &1.args["submission_id"]) |> Enum.uniq() |> length() == 10

    for state <- Oban.Job.unique_states(:incomplete) do
      for job <- jobs do
        job
        |> Ecto.Changeset.change(
          state: Atom.to_string(state),
          inserted_at: DateTime.add(DateTime.utc_now(), -86_400, :second)
        )
        |> Repo.update!()
      end

      response = conn |> recycle() |> submit(%{"question" => "Overflow"}) |> json_response(503)
      assert response == %{"status" => "unavailable", "submitted" => false}
      assert Repo.aggregate(Oban.Job, :count) == 10
    end
  end

  for state <- ~w(completed cancelled discarded) do
    @terminal_state state
    test "a #{@terminal_state} job releases its slot without replacing its question", %{
      conn: conn
    } do
      fill_slots(conn)
      [job | _] = all_enqueued(worker: SendSupportQuestionToDiscord)
      job |> Ecto.Changeset.change(state: @terminal_state) |> Repo.update!()

      response = conn |> recycle() |> submit(%{"question" => "Replacement"}) |> json_response(202)
      assert response["submission_id"] != job.args["submission_id"]

      assert_enqueued(
        worker: SendSupportQuestionToDiscord,
        args: %{
          slot: job.args["slot"],
          question: "Replacement",
          submission_id: response["submission_id"]
        }
      )

      assert Repo.get!(Oban.Job, job.id).args == job.args
      assert Repo.aggregate(Oban.Job, :count) == 11
      assert length(all_enqueued(worker: SendSupportQuestionToDiscord)) == 10
      assert conn |> recycle() |> submit(%{"question" => "Overflow"}) |> json_response(503)
    end
  end

  defp fill_slots(conn) do
    for number <- 1..10 do
      response =
        conn |> recycle() |> submit(%{"question" => "Question #{number}"}) |> json_response(202)

      assert response["submitted"] == true
    end
  end

  defp submit(conn, params) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/api/support/questions", Jason.encode!(params))
  end
end
