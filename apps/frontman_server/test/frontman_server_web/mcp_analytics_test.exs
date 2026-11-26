defmodule FrontmanServerWeb.MCPAnalyticsTest do
  use FrontmanServerWeb.ConnCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.BillingFixtures

  alias Anubis.Server.{Context, Frame}
  alias FrontmanServer.Analytics
  alias FrontmanServer.Repo
  alias FrontmanServer.Workers.DeliverHeapEvent
  alias FrontmanServerWeb.MCP.{ConsentIdentity, Server}

  setup do
    previous = Application.get_env(:frontman_server, Analytics)

    Application.put_env(:frontman_server, Analytics,
      enabled: true,
      anonymous_enabled: true,
      app_id: "test"
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:frontman_server, Analytics, previous)
      else
        Application.delete_env(:frontman_server, Analytics)
      end
    end)
  end

  test "handoff records access changes and authorization rejection without request secrets", %{
    conn: conn
  } do
    user = user_fixture()
    subscription = subscription_for_scope_fixture(user_scope_fixture(user), %{status: "past_due"})
    identity_fixture(user, %{provider: "google"})
    identity_fixture(user, %{provider: "github"})

    started =
      conn
      |> log_in_user(user)
      |> get("/auth/mcp/workos?external_auth_id=private-external-request&client=chatgpt")

    pending = get_session(started, :connect_handoff)
    attempt = get_session(started, :onboarding_attempt_id)
    assert {:ok, ^attempt} = Ecto.UUID.cast(attempt)

    shown = started |> recycle() |> get(redirected_to(started))
    assert html_response(shown, 200)
    assert_event("mcp_connection_started", %{"onboarding_attempt_id" => attempt})
    assert_event("mcp_access_evaluated", %{"access_status" => "blocked"})

    subscription |> Ecto.Changeset.change(status: "active") |> Repo.update!()
    rechecked = shown |> recycle() |> get("/auth/mcp/workos/pending", ref: pending["ref"])
    assert html_response(rechecked, 200)

    assert_event("mcp_access_rechecked", %{
      "previous_access_status" => "blocked",
      "access_status" => "allowed"
    })

    rejected = rechecked |> recycle() |> post("/auth/mcp/workos/pending", ref: pending["ref"])
    assert response(rejected, 400)
    assert_event("mcp_authorization_submitted", %{})
    assert_event("mcp_authorization_failed", %{"reason_code" => "authorization_failed"})

    jobs = all_enqueued(worker: DeliverHeapEvent)
    refute inspect(jobs) =~ "private-external-request"
    refute inspect(jobs) =~ pending["ref"]
    refute inspect(jobs) =~ user.email
    refute inspect(jobs) =~ "chatgpt"
  end

  test "account switching preserves attempt and expiration is observed once", %{conn: conn} do
    started =
      conn
      |> log_in_user(user_fixture())
      |> get("/auth/mcp/workos?external_auth_id=private")

    pending = get_session(started, :connect_handoff)
    attempt = get_session(started, :onboarding_attempt_id)

    switched =
      started |> recycle() |> post("/auth/mcp/workos/switch-account", ref: pending["ref"])

    assert redirected_to(switched) == "/users/log-in"
    assert get_session(switched, :onboarding_attempt_id) == attempt
    assert_event("mcp_account_switch_requested", %{"onboarding_attempt_id" => attempt})

    expired =
      switched
      |> get_session(:connect_handoff)
      |> Map.put("started_at", System.system_time(:second) - 901)

    returned =
      switched
      |> recycle()
      |> init_test_session(connect_handoff: expired, onboarding_attempt_id: attempt)
      |> get("/users/log-in")

    assert html_response(returned, 200)
    refute get_session(returned, :connect_handoff)
    assert_event("mcp_connection_expired", %{"onboarding_attempt_id" => attempt})
    assert returned |> recycle() |> get("/users/log-in") |> html_response(200)
    assert length(events("mcp_connection_expired")) == 1
  end

  test "authenticated MCP requests dedupe connections and record only safe completion properties" do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))
    frame = %Frame{context: %Context{auth: %{sub: user.id, client_id: "registered-client"}}}

    assert {:reply, _, _} = Server.handle_request(%{"method" => "tools/list"}, frame)

    request = %{
      "method" => "tools/call",
      "params" => %{"name" => "list_sites", "arguments" => %{"private" => "secret-payload"}}
    }

    assert {:reply, _, _} = Server.handle_request(request, frame)
    assert {:reply, _, _} = Server.handle_request(request, frame)
    assert length(events("mcp_client_connected")) == 1
    assert_event("mcp_tools_list_completed", %{"outcome" => "succeeded"})
    assert_event("mcp_sites_list_completed", %{"count" => 0})
    assert_event("mcp_tool_call_completed", %{"tool_name" => "list_sites"})

    assert {:error, _, _} = Server.handle_request(request, %Frame{})
    assert length(events("mcp_client_connected")) == 1
    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "secret-payload"
    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "registered-client"
  end

  test "client labels require an exact authenticated registry match" do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))

    config =
      Analytics.config()
      |> Keyword.put(:mcp_clients, %{"https://chatgpt.com/oauth/client.json" => "chatgpt"})

    Application.put_env(:frontman_server, Analytics, config)

    frame = %Frame{
      context: %Context{auth: %{sub: user.id, client_id: "https://chatgpt.com/oauth/client.json"}}
    }

    assert {:reply, _, _} = Server.handle_request(%{"method" => "tools/list"}, frame)
    assert_event("mcp_client_connected", %{"mcp_client" => "chatgpt"})
    assert_event("mcp_tools_list_completed", %{"mcp_client" => "chatgpt"})

    unregistered = %Frame{
      context: %Context{auth: %{sub: user.id, client_id: "https://chatgpt.com/unregistered"}}
    }

    assert {:reply, _, _} = Server.handle_request(%{"method" => "tools/list"}, unregistered)
    assert_event("mcp_client_connected", %{"mcp_client" => "unknown"})
    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "https://chatgpt.com"
  end

  test "verified consent correlates tool events without inventing a browser attempt" do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))

    auth = %{
      sub: user.id,
      client_id: "registered-client",
      raw_claims: %{"sid" => "private-consent", "jti" => "private-token-id"}
    }

    frame = %Frame{context: %Context{auth: auth}}
    expected = ConsentIdentity.properties(auth).mcp_connection_id

    assert {:reply, _, _} = Server.handle_request(%{"method" => "tools/list"}, frame)
    assert_event("mcp_tools_list_completed", %{"mcp_connection_id" => expected})

    [event] = events("mcp_tools_list_completed")
    refute Map.has_key?(event.args["properties"], "onboarding_attempt_id")
    refute inspect(event.args) =~ "private-consent"
    refute inspect(event.args) =~ "private-token-id"
    refute inspect(event.args) =~ "registered-client"
  end

  @tag :wordpress_runtime
  @tag skip: System.get_env("FRONTMAN_WP_RUNTIME_URL") == nil
  test "only successful WordPress operations activate and analytics failure does not fail tools" do
    user = user_fixture()
    scope = user_scope_fixture(user)
    subscription_for_scope_fixture(scope)
    url = System.fetch_env!("FRONTMAN_WP_RUNTIME_URL")

    assert {:ok, site_id} =
             FrontmanServer.WordPress.connect(scope, %{
               "catalog_url" => url,
               "call_url" => url <> "/call",
               "username" => "admin",
               "password" => File.read!(System.fetch_env!("FRONTMAN_WP_RUNTIME_PASSWORD"))
             })

    frame = %Frame{context: %Context{auth: %{sub: user.id, client_id: "runtime-client"}}}

    call = fn name, arguments ->
      Server.handle_request(
        %{"method" => "tools/call", "params" => %{"name" => name, "arguments" => arguments}},
        frame
      )
    end

    assert {:reply, _, _} = Server.handle_request(%{"method" => "tools/list"}, frame)
    assert {:reply, _, _} = call.("list_sites", %{})
    assert events("mcp_activated") == []

    assert {:reply, %{"isError" => true}, _} =
             call.("wp_read_post", %{"site_id" => site_id, "id" => 2_147_483_647})

    assert events("mcp_activated") == []

    Repo.query!("""
    ALTER TABLE oban_jobs ADD CONSTRAINT reject_activation_runtime_test
    CHECK (args->>'event' IS DISTINCT FROM 'mcp_activated')
    """)

    assert {:reply, %{"isError" => false}, _} =
             call.("wp_get_site_info", %{"site_id" => site_id})

    assert events("mcp_activated") == []
    Repo.query!("ALTER TABLE oban_jobs DROP CONSTRAINT reject_activation_runtime_test")

    assert {:reply, %{"isError" => false}, _} =
             call.("wp_get_site_info", %{"site_id" => site_id})

    assert length(events("mcp_activated")) == 2
    assert_event("mcp_activated", %{"activation_scope" => "user", "operation_kind" => "unknown"})
    assert_event("mcp_activated", %{"activation_scope" => "user_client"})

    assert {:reply, %{"isError" => false}, _} =
             call.("wp_get_site_info", %{"site_id" => site_id})

    assert length(events("mcp_activated")) == 2
    refute inspect(events("mcp_activated")) =~ "runtime-client"
    refute inspect(events("mcp_activated")) =~ url
  end

  defp assert_event(event, properties) do
    assert Enum.any?(events(event), fn job ->
             Map.take(job.args["properties"], Map.keys(properties)) == properties
           end)
  end

  defp events(event) do
    Enum.filter(all_enqueued(worker: DeliverHeapEvent), &(&1.args["event"] == event))
  end
end
