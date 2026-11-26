defmodule FrontmanServerWeb.AnalyticsControllerTest do
  use FrontmanServerWeb.ConnCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.BillingFixtures

  alias FrontmanServer.Analytics
  alias FrontmanServer.Workers.DeliverHeapEvent
  alias FrontmanServerWeb.Endpoint

  setup do
    previous = Application.get_env(:frontman_server, Analytics)
    Application.put_env(:frontman_server, Analytics, enabled: true, anonymous_enabled: true)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:frontman_server, Analytics)
        config -> Application.put_env(:frontman_server, Analytics, config)
      end
    end)

    :ok
  end

  test "render does not record a view; browser acknowledgement queues once with opaque request ID",
       %{
         conn: conn
       } do
    sensitive = "private-caller-controlled-request-id"
    shown = conn |> put_req_header("x-request-id", sensitive) |> get(~p"/users/log-in")
    [receipt] = receipts(shown)
    assert all_enqueued(worker: DeliverHeapEvent) == []

    for _ <- 1..2 do
      assert shown |> acknowledge(receipt) |> response(204) == ""
    end

    [job] = all_enqueued(worker: DeliverHeapEvent)
    properties = job.args["properties"]
    assert job.args["event"] == "auth_screen_viewed"
    assert properties["event_source"] == "hosted_browser"
    assert properties["entry_surface"] == "hosted"
    assert properties["onboarding_attempt_id"] == get_session(shown, :onboarding_attempt_id)

    assert properties["request_id"] ==
             :crypto.mac(:hmac, :sha256, Endpoint.config(:secret_key_base), sensitive)
             |> Base.url_encode64(padding: false)

    refute inspect(job.args) =~ sensitive
  end

  test "billing setup receipt is present only for a blocked checkpoint", %{conn: conn} do
    for {status, expected_count} <- [{"past_due", 2}, {"active", 1}] do
      user = user_fixture()
      subscription_for_scope_fixture(user_scope_fixture(user), %{status: status})

      started =
        conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private-request")

      shown = started |> recycle() |> get(redirected_to(started))
      receipts = receipts(shown)
      assert length(receipts) == expected_count

      for receipt <- receipts do
        assert shown |> acknowledge(receipt) |> response(204) == ""
      end

      jobs =
        all_enqueued(worker: DeliverHeapEvent)
        |> Enum.filter(&(&1.args["identity"] == user.id))

      assert Enum.any?(jobs, &(&1.args["event"] == "mcp_checkpoint_viewed"))

      assert Enum.any?(jobs, &(&1.args["event"] == "billing_setup_viewed")) ==
               (status == "past_due")

      refute inspect(jobs) =~ user.email
      refute inspect(jobs) =~ "private-request"
    end
  end

  test "receipt cannot be tampered with, used in another attempt, or used after account change",
       %{
         conn: conn
       } do
    shown = get(conn, ~p"/users/log-in")
    [receipt] = receipts(shown)
    assert shown |> acknowledge(receipt <> "tampered") |> response(400) == ""

    other = get(build_conn(), ~p"/users/log-in")
    assert other |> acknowledge(receipt) |> response(400) == ""

    authenticated =
      shown
      |> recycle()
      |> log_in_user(user_fixture())
      |> put_session(:onboarding_attempt_id, get_session(shown, :onboarding_attempt_id))
      |> get(~p"/billing/stripe-return/customer-portal")

    assert authenticated |> acknowledge(receipt) |> response(400) == ""
    assert all_enqueued(worker: DeliverHeapEvent) == []
  end

  test "expired receipts and signed non-view events are rejected", %{conn: conn} do
    shown = get(conn, ~p"/users/log-in")
    [receipt] = receipts(shown)
    {:ok, payload} = Phoenix.Token.verify(Endpoint, "hosted-page-view", receipt, max_age: 900)

    expired =
      Phoenix.Token.sign(Endpoint, "hosted-page-view", payload,
        signed_at: System.system_time(:second) - 901
      )

    non_view =
      Phoenix.Token.sign(Endpoint, "hosted-page-view", %{payload | event: "auth_completed"})

    assert shown |> acknowledge(expired) |> response(400) == ""
    assert shown |> acknowledge(non_view) |> response(400) == ""
    assert all_enqueued(worker: DeliverHeapEvent) == []
  end

  test "browser endpoint requires CSRF protection", %{conn: conn} do
    shown = get(conn, ~p"/users/log-in")
    [receipt] = receipts(shown)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      shown
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post(~p"/analytics/page-view", %{receipt: receipt})
    end

    assert all_enqueued(worker: DeliverHeapEvent) == []
  end

  test "disabled collection produces no receipt and revocation prevents admission", %{conn: conn} do
    shown = get(conn, ~p"/users/log-in")
    [receipt] = receipts(shown)
    Application.put_env(:frontman_server, Analytics, enabled: false, anonymous_enabled: true)
    assert receipts(get(build_conn(), ~p"/users/log-in")) == []
    assert shown |> acknowledge(receipt) |> response(204) == ""

    Application.put_env(:frontman_server, Analytics, enabled: true, anonymous_enabled: false)
    assert receipts(get(build_conn(), ~p"/users/log-in")) == []
    assert shown |> acknowledge(receipt) |> response(204) == ""
    assert all_enqueued(worker: DeliverHeapEvent) == []
  end

  defp receipts(conn) do
    conn
    |> html_response(200)
    |> LazyHTML.from_document()
    |> LazyHTML.query("[data-page-view-receipt]")
    |> LazyHTML.attribute("data-page-view-receipt")
  end

  defp acknowledge(conn, receipt) do
    [csrf] =
      conn
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("meta[name=csrf-token]")
      |> LazyHTML.attribute("content")

    conn
    |> recycle()
    |> put_private(:plug_skip_csrf_protection, false)
    |> put_req_header("x-csrf-token", csrf)
    |> put_req_header("content-type", "application/json")
    |> post(~p"/analytics/page-view", Jason.encode!(%{receipt: receipt}))
  end
end
