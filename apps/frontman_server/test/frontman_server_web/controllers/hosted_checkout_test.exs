defmodule FrontmanServerWeb.HostedCheckoutTest do
  use FrontmanServerWeb.ConnCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.BillingFixtures

  alias FrontmanServer.{Accounts, Billing}

  setup :setup_paper_tiger

  test "browser checkout preserves the original journey and waits for a signed webhook", %{
    conn: conn
  } do
    user = user_fixture()
    insert_site(user)
    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=original")
    pending = get_session(conn, :connect_handoff)
    conn = conn |> recycle() |> get(redirected_to(conn))
    document = conn |> html_response(200) |> LazyHTML.from_document()
    form = LazyHTML.query(document, "#checkout-plan")

    assert LazyHTML.query(form, "input[type=radio]") |> LazyHTML.attribute("value") == [
             "monthly",
             "yearly"
           ]

    assert length(LazyHTML.query(form, "button") |> LazyHTML.to_tree()) == 1
    [csrf] = form |> LazyHTML.query("input[name=_csrf_token]") |> LazyHTML.attribute("value")

    checkout =
      conn
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/wordpress/connect/checkout", %{
        ref: pending["ref"],
        interval: "monthly",
        _csrf_token: csrf,
        success_url: "https://untrusted.example"
      })

    assert redirected_to(checkout) =~ "http://localhost:"
    assert get_session(checkout, :connect_handoff) == pending

    assert [%{params: params}] =
             PaperTiger.Test.requests(method: :post, path: "/v1/checkout/sessions")

    assert params["success_url"] =~
             "/auth/mcp/workos/pending?ref=#{pending["ref"]}&checkout=success"

    assert params["cancel_url"] =~
             "/auth/mcp/workos/pending?ref=#{pending["ref"]}&checkout=cancel"

    refute params["success_url"] =~ "untrusted"
    assert params["payment_method_collection"] == "always"
    assert params["subscription_data"]["trial_period_days"] == "7"
    scope = Accounts.Scope.for_user(user)
    assert Billing.subscription_access(scope) == :none

    returned =
      checkout
      |> recycle()
      |> get("/auth/mcp/workos/pending", ref: pending["ref"], checkout: "success")

    assert html_response(returned, 200) =~ "checking payment confirmation"
    assert Billing.subscription_access(scope) == :none
    before = returned |> recycle() |> get("/wordpress/connect/status", ref: pending["ref"])
    revision = json_response(before, 200)["revision"]

    event = %{
      "id" => "evt_#{Ecto.UUID.generate()}",
      "type" => "customer.subscription.created",
      "data" => %{
        "object" => %{
          "id" => "sub_#{Ecto.UUID.generate()}",
          "customer" => "cus_#{Ecto.UUID.generate()}",
          "status" => "trialing",
          "metadata" => params["subscription_data"]["metadata"]
        }
      }
    }

    assert signed_webhook(event) |> response(200)
    assert Billing.subscription_access(scope) == {:allowed, "trialing"}
    after_webhook = returned |> recycle() |> get("/wordpress/connect/status", ref: pending["ref"])
    assert json_response(after_webhook, 200)["revision"] != revision
    assert get_session(after_webhook, :connect_handoff) == pending
  end

  test "checkout and portal require authenticated browser sessions and CSRF", %{conn: conn} do
    for path <- ["/wordpress/connect/checkout", "/wordpress/connect/portal"] do
      assert conn |> post(path, interval: "monthly") |> redirected_to() == "/users/log-in"
      signed_in = log_in_user(conn, user_fixture())

      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        signed_in
        |> put_private(:plug_skip_csrf_protection, false)
        |> post(path, interval: "monthly")
      end
    end

    assert PaperTiger.Test.requests(method: :post, path: "/v1/checkout/sessions") == []
  end

  test "expired or mismatched references cannot purchase and active accounts never see offers", %{
    conn: conn
  } do
    scope = scope_with_allowed_access_fixture()
    started = conn |> log_in_user(scope.user) |> get("/auth/mcp/workos?external_auth_id=original")
    pending = get_session(started, :connect_handoff)
    shown = started |> recycle() |> get(redirected_to(started))
    refute html_response(shown, 200) =~ ~s(id="checkout-monthly")

    assert shown
           |> recycle()
           |> post("/wordpress/connect/checkout", ref: "wrong", interval: "monthly")
           |> html_response(400) =~ "Your setup is saved"

    assert shown
           |> recycle()
           |> post("/wordpress/connect/checkout", ref: pending["ref"], interval: "monthly")
           |> redirected_to() =~ pending["ref"]

    assert PaperTiger.Test.requests(method: :post, path: "/v1/checkout/sessions") == []
  end

  test "generic purchase stays generic and trial-ineligible users receive no trial", %{conn: conn} do
    scope = user_scope_fixture()
    insert_site(scope.user)

    subscription_for_scope_fixture(scope, %{
      status: "canceled",
      trial_start: ~U[2026-01-01 00:00:00Z],
      trial_end: ~U[2026-01-08 00:00:00Z]
    })

    conn = conn |> log_in_user(scope.user) |> get("/wordpress/connect")
    assert html_response(conn, 200) =~ "Continue to checkout"
    refute conn.resp_body =~ "days free"

    checkout =
      conn |> recycle() |> post("/wordpress/connect/checkout", interval: "yearly", ref: "")

    assert redirected_to(checkout) =~ "http://localhost:"

    assert [%{params: params}] =
             PaperTiger.Test.requests(method: :post, path: "/v1/checkout/sessions")

    assert params["success_url"] =~ "/wordpress/connect?checkout=success"
    refute Map.has_key?(params["subscription_data"], "trial_period_days")
  end

  test "inactive customers recover in the portal and return to the same journey", %{conn: conn} do
    scope = user_scope_fixture()
    insert_site(scope.user)

    customer =
      Req.post!(PaperTiger.Test.base_url("/v1/customers"),
        headers: PaperTiger.Test.auth_headers(),
        form: [email: scope.user.email]
      ).body

    {:ok, billing_customer} = Billing.upsert_customer(scope, customer["id"])

    {:ok, _subscription} =
      Billing.upsert_subscription(scope, billing_customer, %{
        stripe_subscription_id: "sub_portal",
        status: "past_due",
        interval: "monthly"
      })

    started = conn |> log_in_user(scope.user) |> get("/auth/mcp/workos?external_auth_id=original")
    pending = get_session(started, :connect_handoff)
    shown = started |> recycle() |> get(redirected_to(started))
    assert html_response(shown, 200) =~ ~s(id="connect-billing-portal")
    refute shown.resp_body =~ ~s(id="checkout-monthly")
    portal = shown |> recycle() |> post("/wordpress/connect/portal", ref: pending["ref"])
    assert redirected_to(portal)

    assert [%{params: params}] =
             PaperTiger.Test.requests(method: :post, path: "/v1/billing_portal/sessions")

    assert params["customer"] == customer["id"]
    assert params["return_url"] =~ "/auth/mcp/workos/pending?ref=#{pending["ref"]}"
    assert get_session(portal, :connect_handoff) == pending
    assert Billing.subscription_access(scope) == {:inactive, "past_due"}
  end

  defp insert_site(user) do
    FrontmanServer.Repo.insert!(%FrontmanServer.WordPress.Connection{
      user_id: user.id,
      catalog_url: "https://owned.example/wp-json/frontman/v1/tools",
      call_url: "https://owned.example/wp-json/frontman/v1/tools/call",
      username: "synthetic-user",
      password: "synthetic-password"
    })
  end

  defp signed_webhook(event) do
    body = Jason.encode!(event)
    timestamp = System.system_time(:second)
    secret = Application.fetch_env!(:frontman_server, :stripe)[:webhook_secret]

    signature =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{body}") |> Base.encode16(case: :lower)

    build_conn()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("stripe-signature", "t=#{timestamp},v1=#{signature}")
    |> post("/api/stripe/webhook", body)
  end
end
