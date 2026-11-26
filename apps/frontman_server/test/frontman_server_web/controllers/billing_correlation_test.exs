defmodule FrontmanServerWeb.BillingCorrelationTest do
  use FrontmanServerWeb.ConnCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts
  alias FrontmanServer.Analytics
  alias FrontmanServer.Billing
  alias FrontmanServer.Workers.DeliverHeapEvent

  @origin "https://customer.example"

  setup :setup_paper_tiger

  setup do
    previous = Application.get_env(:frontman_server, Analytics)
    Application.put_env(:frontman_server, Analytics, enabled: true, app_id: "test")

    on_exit(fn ->
      if previous,
        do: Application.put_env(:frontman_server, Analytics, previous),
        else: Application.delete_env(:frontman_server, Analytics)
    end)

    %{user: user_fixture()}
  end

  test "hosted issuance carries its attempt through bearer checkout and verified webhook", %{
    user: user
  } do
    attempt = Ecto.UUID.generate()
    auth = issue_token(user, attempt, System.system_time(:second))
    other = user_fixture()

    conn =
      build_conn()
      |> log_in_user(other)
      |> put_session(:onboarding_attempt_id, Ecto.UUID.generate())
      |> put_embedded_client_bearer(auth)
      |> post(~p"/api/billing/checkout", %{
        interval: "monthly",
        user_id: other.id,
        onboarding_attempt_id: Ecto.UUID.generate()
      })

    assert json_response(conn, 200)["url"]
    assert [%{params: params}] = checkout_requests()
    assert params["metadata"]["user_id"] == user.id
    assert params["metadata"]["onboarding_attempt_id"] == attempt
    assert params["subscription_data"]["metadata"]["onboarding_attempt_id"] == attempt
    assert params["subscription_data"]["metadata"]["user_id"] == user.id

    assert_enqueued(
      worker: DeliverHeapEvent,
      args: %{
        event: "checkout_started",
        properties: %{onboarding_attempt_id: attempt, entry_surface: "editor"}
      }
    )

    event = subscription_event(params["subscription_data"]["metadata"])
    assert signed_webhook(event) |> response(200)
    assert Billing.subscription_access(Accounts.Scope.for_user(user)) == {:allowed, "active"}

    assert_enqueued(
      worker: DeliverHeapEvent,
      args: %{
        event: "subscription_access_changed",
        identity: user.id,
        properties: %{onboarding_attempt_id: attempt}
      }
    )

    assert signed_webhook(event) |> response(200)
    assert length(access_events()) == 1

    unchanged = Map.put(event, "id", event["id"] <> "_unchanged")
    assert signed_webhook(unchanged) |> response(200)
    assert length(access_events()) == 1
  end

  test "missing, invalid and expired issuance attempts renew on authenticated reconnect",
       %{
         user: user
       } do
    for {attempt, started_at} <- [
          {nil, nil},
          {"not-a-uuid", System.system_time(:second)},
          {Ecto.UUID.generate(), System.system_time(:second) - 901},
          {Ecto.UUID.generate(), nil}
        ] do
      auth = issue_token(user, attempt, started_at)

      assert {_scope, _id, %{onboarding_attempt_id: renewed}} =
               Accounts.get_scope_and_context_by_embedded_client_token(auth.token, @origin)

      assert {:ok, ^renewed} = Ecto.UUID.cast(renewed)
      refute renewed == attempt

      conn =
        build_conn()
        |> log_in_user(user)
        |> put_session(:onboarding_attempt_id, Ecto.UUID.generate())
        |> put_embedded_client_bearer(auth)
        |> post(~p"/api/billing/checkout", %{
          interval: "yearly",
          onboarding_attempt_id: Ecto.UUID.generate()
        })

      assert json_response(conn, 200)["url"]
    end

    for %{params: params} <- checkout_requests() do
      assert {:ok, _id} = Ecto.UUID.cast(params["metadata"]["onboarding_attempt_id"])

      assert params["metadata"]["onboarding_attempt_id"] ==
               params["subscription_data"]["metadata"]["onboarding_attempt_id"]
    end
  end

  test "old tokens remain usable without correlation and wrong origins cannot use new tokens", %{
    user: user
  } do
    token = Accounts.generate_embedded_client_token(user, @origin)
    assert {_scope, _id} = Accounts.get_scope_by_embedded_client_token(token, @origin)

    conn =
      build_conn()
      |> put_embedded_client_bearer(%{token: token, origin: @origin})
      |> post(~p"/api/billing/checkout", %{interval: "monthly"})

    assert json_response(conn, 200)["url"]
    auth = issue_token(user, Ecto.UUID.generate(), System.system_time(:second))

    rejected =
      build_conn()
      |> log_in_user(user)
      |> put_embedded_client_bearer(%{auth | origin: "https://other.example"})
      |> post(~p"/api/billing/checkout", %{interval: "monthly"})

    assert response(rejected, 401)
    assert length(checkout_requests()) == 1
  end

  test "invalid webhook attempt metadata is omitted without losing authoritative access", %{
    user: user
  } do
    event = subscription_event(%{"user_id" => user.id, "onboarding_attempt_id" => "invalid"})
    assert signed_webhook(event) |> response(200)
    [job] = access_events()
    refute Map.has_key?(job.args["properties"], "onboarding_attempt_id")
    assert job.args["identity"] == user.id
  end

  test "a valid but older bearer token no longer attributes checkout to its issuance attempt", %{
    user: user
  } do
    auth = issue_token(user, Ecto.UUID.generate(), System.system_time(:second))
    {_scope, token_id} = Accounts.get_scope_by_embedded_client_token(auth.token, @origin)

    Accounts.UserToken
    |> FrontmanServer.Repo.get!(token_id)
    |> Ecto.Changeset.change(inserted_at: DateTime.add(DateTime.utc_now(:second), -901))
    |> FrontmanServer.Repo.update!()

    conn =
      build_conn()
      |> put_embedded_client_bearer(auth)
      |> post(~p"/api/billing/checkout", %{interval: "monthly"})

    assert json_response(conn, 200)["url"]
    assert [%{params: params}] = checkout_requests()
    refute Map.has_key?(params["metadata"], "onboarding_attempt_id")
  end

  test "expired handoff cannot be revived by a recent ordinary auth timestamp", %{user: user} do
    attempt = Ecto.UUID.generate()

    conn =
      build_conn()
      |> log_in_user(user)
      |> put_session(:onboarding_attempt_id, attempt)
      |> put_session(:onboarding_attempt_started_at, System.system_time(:second))
      |> put_session(:connect_handoff, %{
        "ref" => "expired",
        "user_id" => user.id,
        "started_at" => System.system_time(:second) - 901
      })
      |> post(~p"/users/log-in", %{
        "_action" => "connect",
        "user_id" => user.id,
        "embedded_origin" => @origin,
        "embedded_state" => "correlation"
      })

    assert [_, token] = Regex.run(~r/data-token="([^"]+)"/, html_response(conn, 200))

    assert {_scope, _id, %{onboarding_attempt_id: renewed}} =
             Accounts.get_scope_and_context_by_embedded_client_token(token, @origin)

    assert {:ok, ^renewed} = Ecto.UUID.cast(renewed)
    refute renewed == attempt
    assert get_session(conn, :onboarding_attempt_id) == renewed

    assert abs(System.system_time(:second) - get_session(conn, :onboarding_attempt_started_at)) <=
             1
  end

  test "handoff context must match both the authenticated account and session attempt", %{
    user: user
  } do
    attempt = Ecto.UUID.generate()

    for {handoff_user, handoff_attempt, expected} <- [
          {user.id, attempt, attempt},
          {Ecto.UUID.generate(), attempt, nil},
          {user.id, Ecto.UUID.generate(), nil}
        ] do
      conn =
        build_conn()
        |> log_in_user(user)
        |> put_session(:onboarding_attempt_id, attempt)
        |> put_session(:connect_handoff, %{
          "ref" => "pending",
          "user_id" => handoff_user,
          "onboarding_attempt_id" => handoff_attempt,
          "started_at" => System.system_time(:second)
        })
        |> post(~p"/users/log-in", %{
          "_action" => "connect",
          "user_id" => user.id,
          "embedded_origin" => @origin,
          "embedded_state" => "correlation"
        })

      assert [_, token] = Regex.run(~r/data-token="([^"]+)"/, html_response(conn, 200))

      assert {_scope, _id, %{onboarding_attempt_id: actual}} =
               Accounts.get_scope_and_context_by_embedded_client_token(token, @origin)

      case expected do
        nil ->
          assert {:ok, ^actual} = Ecto.UUID.cast(actual)
          refute actual == attempt

        ^attempt ->
          assert actual == attempt
      end
    end
  end

  defp issue_token(user, attempt, started_at) do
    conn =
      build_conn()
      |> log_in_user(user)
      |> put_session(:onboarding_attempt_id, attempt)
      |> put_session(:onboarding_attempt_started_at, started_at)
      |> post(~p"/users/log-in", %{
        "_action" => "connect",
        "user_id" => user.id,
        "embedded_origin" => @origin,
        "embedded_state" => "correlation"
      })

    assert [_, token] = Regex.run(~r/data-token="([^"]+)"/, html_response(conn, 200))
    %{token: token, origin: @origin}
  end

  defp checkout_requests,
    do: PaperTiger.Test.requests(method: :post, path: "/v1/checkout/sessions")

  defp access_events,
    do: all_enqueued(worker: DeliverHeapEvent, args: %{event: "subscription_access_changed"})

  defp subscription_event(metadata) do
    id = Ecto.UUID.generate()

    %{
      "id" => "evt_#{id}",
      "type" => "customer.subscription.created",
      "data" => %{
        "object" => %{
          "id" => "sub_#{id}",
          "customer" => "cus_#{id}",
          "status" => "active",
          "metadata" => metadata
        }
      }
    }
  end

  defp signed_webhook(event) do
    body = Jason.encode!(event)
    timestamp = System.system_time(:second)
    secret = Application.fetch_env!(:frontman_server, :stripe)[:webhook_secret]

    signature =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{body}")
      |> Base.encode16(case: :lower)

    build_conn()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("stripe-signature", "t=#{timestamp},v1=#{signature}")
    |> post(~p"/api/stripe/webhook", body)
  end
end
