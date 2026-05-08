defmodule FrontmanServerWeb.StripeWebhookControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import Mox

  alias FrontmanServer.Billing.StripeEvent
  alias FrontmanServer.Repo

  setup :verify_on_exit!

  test "verifies and processes webhook with raw body", %{conn: conn} do
    raw_body =
      Jason.encode!(%{"id" => "evt_webhook", "type" => "checkout.session.async_payment_failed"})

    expect(FrontmanServer.Billing.ClientMock, :construct_webhook_event, fn ^raw_body,
                                                                           "t=1,v1=sig" ->
      {:ok,
       %{"id" => "evt_webhook", "type" => "checkout.session.async_payment_failed", "data" => %{}}}
    end)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", "t=1,v1=sig")
      |> post(~p"/api/stripe/webhook", raw_body)

    assert %{"status" => "ok", "result" => "ignored"} = json_response(conn, 200)
    assert %StripeEvent{} = Repo.get_by(StripeEvent, stripe_event_id: "evt_webhook")
  end

  test "rejects invalid webhook signatures", %{conn: conn} do
    expect(FrontmanServer.Billing.ClientMock, :construct_webhook_event, fn _raw_body,
                                                                           _signature ->
      {:error, :invalid_signature}
    end)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/stripe/webhook", Jason.encode!(%{"id" => "evt_bad"}))

    assert %{"error" => "invalid_stripe_webhook"} = json_response(conn, 400)
  end
end
