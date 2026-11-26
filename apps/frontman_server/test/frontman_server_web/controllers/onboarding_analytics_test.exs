defmodule FrontmanServerWeb.OnboardingAnalyticsTest do
  use FrontmanServerWeb.ConnCase, async: false

  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Analytics
  alias FrontmanServer.Billing
  alias FrontmanServer.SubscriptionWebhook
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.Workers.DeliverHeapEvent

  setup do
    previous = Application.get_env(:frontman_server, Analytics)

    Application.put_env(:frontman_server, Analytics,
      enabled: true,
      anonymous_enabled: true,
      app_id: "test"
    )

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:frontman_server, Analytics)
        value -> Application.put_env(:frontman_server, Analytics, value)
      end
    end)

    :ok
  end

  test "failed password authentication records bounded reasons, not credentials", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{onboarding_attempt_id: Ecto.UUID.generate()})
      |> post(~p"/users/log-in", %{
        "user" => %{"email" => "private@example.com", "password" => "private-password"}
      })

    assert html_response(conn, 200) =~ "Invalid email or password"
    assert_event("auth_started", %{"auth_provider" => "password"})
    assert_event("auth_failed", %{"reason_code" => "invalid_credentials"})
    refute_enqueued(worker: DeliverHeapEvent, args: %{event: "auth_completed"})
    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "private"
  end

  test "ordinary hosted authentication creates an attempt without needing MCP", %{conn: conn} do
    conn = post(conn, ~p"/users/log-in", %{"user" => %{"token" => "invalid"}})

    assert html_response(conn, 200) =~ "The link is invalid or it has expired."
    assert {:ok, attempt_id} = Ecto.UUID.cast(get_session(conn, :onboarding_attempt_id))
    assert_event("auth_started", %{"onboarding_attempt_id" => attempt_id})
    assert_event("auth_failed", %{"reason_code" => "invalid_token"})
  end

  test "magic-link request and consumption share one authentication start", %{conn: conn} do
    requested =
      post(conn, ~p"/users/log-in", %{"user" => %{"email" => "unknown@example.com"}})

    consumed =
      requested
      |> recycle()
      |> post(~p"/users/log-in", %{"user" => %{"token" => "expired"}})

    assert html_response(consumed, 200) =~ "The link is invalid or it has expired."
    assert length(all_enqueued(worker: DeliverHeapEvent, args: %{event: "auth_started"})) == 1
  end

  test "validated OAuth state preserves the provider through failure", %{conn: conn} do
    started = post(conn, ~p"/auth/github")
    state = get_session(started, :oauth_signin_state)["state"]

    failed =
      started |> recycle() |> get(~p"/auth/callback?#{%{state: state, error: "access_denied"}}")

    assert redirected_to(failed) == ~p"/users/log-in"
    assert_event("auth_started", %{"auth_provider" => "github"})
    assert_event("auth_failed", %{"auth_provider" => "github"})
  end

  test "disabled transport leaves the login response intact without queueing events", %{
    conn: conn
  } do
    Application.delete_env(:frontman_server, Analytics)
    conn = post(conn, ~p"/users/log-in", %{"user" => %{"token" => "invalid"}})

    assert html_response(conn, 200) =~ "The link is invalid or it has expired."
    assert all_enqueued(worker: DeliverHeapEvent) == []
  end

  test "WordPress validation failure records an attempt without credentials or URLs" do
    user = AccountsFixtures.user_fixture()
    attempt = Ecto.UUID.generate()
    origin = "https://customer.example"

    auth = %{
      token:
        FrontmanServer.Accounts.generate_embedded_client_token(user, origin, %{
          onboarding_attempt_id: attempt
        }),
      origin: origin
    }

    conn =
      bearer_post(build_conn(), auth, ~p"/api/wordpress/connections", %{
        catalog_url: "http://private.example",
        call_url: "http://private.example",
        username: "private-user",
        password: "private-password",
        onboarding_attempt_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        entry_surface: "hosted"
      })

    assert json_response(conn, 422) == %{"error" => "Connection failed"}

    assert_event("site_connection_started", %{
      "framework" => "wordpress",
      "frontman_user_id" => user.id,
      "onboarding_attempt_id" => attempt,
      "entry_surface" => "editor"
    })

    assert_event("site_connection_failed", %{
      "reason_code" => "connection_failed",
      "frontman_user_id" => user.id,
      "onboarding_attempt_id" => attempt,
      "entry_surface" => "editor"
    })

    refute_enqueued(worker: DeliverHeapEvent, args: %{event: "site_connection_completed"})
    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "private"
  end

  test "password login identifies the existing user and preserves the attempt across renewal" do
    user = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    attempt_id = Ecto.UUID.generate()

    conn =
      build_conn()
      |> init_test_session(%{
        onboarding_attempt_id: attempt_id,
        onboarding_attempt_started_at: System.system_time(:second)
      })
      |> post(~p"/users/log-in", %{
        "user" => %{"email" => user.email, "password" => AccountsFixtures.valid_user_password()}
      })

    assert redirected_to(conn)
    assert get_session(conn, :user_token)
    assert get_session(conn, :onboarding_attempt_id) == attempt_id

    assert_event("auth_completed", %{
      "frontman_user_id" => user.id,
      "onboarding_attempt_id" => attempt_id,
      "is_new_user" => false
    })
  end

  test "invalid OAuth state fails without exchanging a provider code" do
    conn =
      build_conn()
      |> init_test_session(%{onboarding_attempt_id: Ecto.UUID.generate()})
      |> get(~p"/auth/callback?#{%{state: "untrusted", code: "private-code"}}")

    assert redirected_to(conn) == ~p"/users/log-in"
    assert_event("auth_failed", %{"auth_provider" => "oauth"})
    refute_enqueued(worker: DeliverHeapEvent, args: %{event: "auth_completed"})
    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "private-code"
  end

  test "checkout return is not proof of subscription access", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/billing/stripe-return/success")

    assert html_response(conn, 200) =~ "Checkout complete."
    assert_event("checkout_returned", %{"outcome" => "success"})
    assert Billing.subscription_access(Scope.for_user(user)) == :none
    refute_enqueued(worker: DeliverHeapEvent, args: %{event: "subscription_access_changed"})
  end

  test "committed subscription changes emit once and duplicate or unchanged webhooks do not" do
    user = AccountsFixtures.user_fixture()
    event = subscription_event(user.id)

    assert {:ok, :processed} = SubscriptionWebhook.process_event(event)

    assert_event("subscription_access_changed", %{
      "frontman_user_id" => user.id,
      "previous_access_status" => "none",
      "access_status" => "allowed",
      "subscription_status" => "active"
    })

    assert {:ok, :duplicate} = SubscriptionWebhook.process_event(event)

    assert {:ok, :processed} =
             SubscriptionWebhook.process_event(Map.put(event, "id", "evt_unchanged"))

    assert length(access_events()) == 1

    inactive =
      event
      |> Map.put("id", "evt_inactive")
      |> put_in(["data", "object", "status"], "past_due")

    assert {:ok, :processed} = SubscriptionWebhook.process_event(inactive)
    assert Billing.subscription_access(Scope.for_user(user)) == {:inactive, "past_due"}

    assert_event("subscription_access_changed", %{
      "previous_access_status" => "allowed",
      "access_status" => "inactive"
    })

    assert length(access_events()) == 2
  end

  test "rejected webhook transaction produces no access event" do
    assert {:error, :account_unavailable} =
             SubscriptionWebhook.process_event(subscription_event(Ecto.UUID.generate()))

    assert access_events() == []
  end

  defp assert_event(event, properties) do
    assert_enqueued(worker: DeliverHeapEvent, args: %{event: event, properties: properties})
  end

  defp access_events do
    all_enqueued(worker: DeliverHeapEvent, args: %{event: "subscription_access_changed"})
  end

  defp subscription_event(user_id) do
    %{
      "id" => "evt_analytics",
      "type" => "customer.subscription.updated",
      "data" => %{
        "object" => %{
          "id" => "sub_analytics",
          "customer" => "cus_analytics",
          "status" => "active",
          "metadata" => %{"user_id" => user_id}
        }
      }
    }
  end
end
