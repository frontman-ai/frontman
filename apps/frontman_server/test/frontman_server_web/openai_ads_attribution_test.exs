defmodule FrontmanServerWeb.OpenAIAdsAttributionTest do
  use FrontmanServerWeb.ConnCase, async: false
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.OpenAIAds
  alias FrontmanServer.OpenAIAds.{Consent, Delivery}
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServerWeb.OpenAIAdsCookie

  setup do
    previous = Application.get_env(:frontman_server, OpenAIAds)
    Application.put_env(:frontman_server, OpenAIAds, enabled: true)
    on_exit(fn -> Application.put_env(:frontman_server, OpenAIAds, previous) end)
  end

  test "only the exact marketing origin can use bounded, private credentialed routes" do
    for origin <- [
          "https://evil.example",
          "http://frontman.sh",
          "https://frontman.sh.evil",
          "null"
        ] do
      denied = ads(build_conn(), :post, grant(), origin)
      assert denied.status == 403
      assert get_resp_header(denied, "access-control-allow-origin") == []
    end

    assert post(build_conn(), "/ads/attribution", grant()).status == 403
    assert ads(build_conn(), :get, %{}).status == 403
    options = ads(build_conn(), :options, %{})
    assert options.status == 204
    assert get_resp_header(options, "access-control-allow-credentials") == ["true"]
    assert get_resp_header(options, "access-control-allow-origin") == ["https://frontman.sh"]
    assert get_resp_header(options, "cache-control") == ["no-store"]
    query = build_conn() |> put_req_header("origin", "https://frontman.sh")
    assert post(query, "/ads/attribution?oppref=private", grant()).status == 403
    assert ads(build_conn(), :post, %{}).status == 422

    assert_error_sent(413, fn ->
      ads(build_conn(), :post, Map.put(grant(), "oppref", String.duplicate("x", 5000)))
    end)

    assert Repo.all(Consent) == []
    Application.put_env(:frontman_server, OpenAIAds, enabled: false)
    assert ads(build_conn(), :post, grant()).status == 403
  end

  test "signed host-only cookie survives authentication; only actual user insertion claims registration" do
    granted = ads(build_conn(), :post, grant())
    assert {granted.params, granted.body_params} == {%{}, %{}}

    assert %{secure: true, http_only: true, same_site: "Lax", path: "/"} =
             cookie = granted.resp_cookies["__Host-frontman_openai_ads"]

    refute Map.has_key?(cookie, :domain)
    conn = %{recycle(granted) | secret_key_base: granted.secret_key_base}
    id = OpenAIAdsCookie.id(conn)
    profile = valid_identity_attributes(%{provider_avatar_url: nil})
    assert {:ok, user} = Accounts.complete_oauth_profile(%Scope{}, profile, nil, id)
    assert {:ok, _} = Accounts.complete_oauth_profile(%Scope{}, profile, nil, id)
    linked = %{profile | provider: "google", provider_id: Ecto.UUID.generate()}
    assert {:ok, _} = Accounts.complete_oauth_profile(%Scope{}, linked, nil, id)
    assert [%Delivery{kind: "registration_completed", status: "pending"}] = Repo.all(Delivery)
    request = OpenAIAds.CAPI.request(Repo.one!(Delivery), "inert-pixel", "inert-key")

    assert %{"events" => [event]} =
             request |> Req.Request.prepare() |> Map.fetch!(:body) |> Jason.decode!()

    assert event["type"] == "registration_completed"
    assert event["data"] == %{"type" => "customer_action"}
    refute Map.has_key?(event, "custom_event_name")
    assert Repo.get!(Consent, id).user_id == user.id
    other = user_fixture()
    {token, _} = generate_user_magic_link_token(other)
    fresh = ads(build_conn(), :post, grant())
    fresh |> recycle() |> post("/users/log-in", %{"user" => %{"token" => token}})
    assert Repo.get_by!(Consent, user_id: other.id).oppref == " opaque+/ "
    assert Repo.aggregate(Delivery, :count) == 1

    saved =
      granted |> recycle() |> log_in_user(user) |> ads(:post, Map.put(grant(), "oppref", nil))

    assert OpenAIAdsCookie.id(%{recycle(saved) | secret_key_base: saved.secret_key_base}) == id
    denied = saved |> recycle() |> ads(:delete, %{})
    assert denied.status == 204
    assert %Delivery{status: "suppressed", oppref: nil} = Repo.one!(Delivery)
  end

  test "a cookie from a logged-out or foreign account starts new attribution without stealing it" do
    owner = user_fixture()
    granted = build_conn() |> log_in_user(owner) |> ads(:post, grant())
    original = Repo.get_by!(Consent, user_id: owner.id)

    cookie_only =
      put_req_cookie(
        build_conn(),
        "__Host-frontman_openai_ads",
        granted.resp_cookies["__Host-frontman_openai_ads"].value
      )

    anonymous = ads(cookie_only, :post, Map.put(grant(), "oppref", nil))
    assert anonymous.status == 204
    foreign = cookie_only |> log_in_user(user_fixture())
    assert ads(foreign, :post, grant()).status == 204
    assert Repo.get!(Consent, original.id) == original
    assert Repo.aggregate(Consent, :count) == 3
  end

  test "embedded conversion waits for a successful editing terminal in the same turn" do
    scope = user_scope_fixture()
    :ok = OpenAIAds.record(scope, "registration_completed", scope.user.id)
    edit = Delivery.milestone(scope.user.id, "first_successful_edit")
    task = task_fixture(scope)

    for {name, payload, outcome} <- [
          {"wp_update_post", %{"content" => [%{"type" => "text", "text" => "updated"}]},
           :completed},
          {"wp_update_post", %{"changed" => false}, :completed},
          {"write_file", %{"changed" => true}, :cancelled}
        ] do
      complete_tool(scope, task, name, payload, outcome)
      refute Repo.exists?(edit)
    end

    complete_tool(scope, task, "wc_update_product_meta", %{"changed" => true}, :completed)
    assert %Delivery{status: "suppressed"} = first = Repo.one!(edit)
    assert ads(build_conn() |> log_in_user(scope.user), :post, grant()).status == 204
    complete_tool(scope, task, "wp_update_term_seo", %{"changed" => true}, :completed)
    assert Repo.one!(edit) == first

    permitted = user_scope_fixture()
    :ok = OpenAIAds.record(permitted, "registration_completed", permitted.user.id)
    assert ads(build_conn() |> log_in_user(permitted.user), :post, grant()).status == 204

    complete_tool(
      permitted,
      task_fixture(permitted),
      "wp_update_post_type_archive_seo",
      %{"changed" => true},
      :completed
    )

    assert %Delivery{status: "pending", oppref: " opaque+/ "} =
             Repo.one!(Delivery.milestone(permitted.user.id, "first_successful_edit"))
  end

  defp complete_tool(scope, task, name, result, outcome) do
    deliveries = Repo.all(Delivery)
    turn = start_turn_fixture(scope, task.id)
    call = %SwarmAi.ToolCall{id: Ecto.UUID.generate(), name: name, arguments: "{}"}
    assert {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :synchronous)
    assert {:ok, _, :no_executor} = Tasks.resolve_tool_request(scope, task.id, call, result)
    assert Repo.all(Delivery) == deliveries
    assert {:ok, _} = Tasks.record_execution_outcome(scope, task.id, turn, outcome)
  end

  defp grant,
    do: %{
      "advertising_consent" => true,
      "oppref" => " opaque+/ ",
      "consent_updated_at_ms" => System.system_time(:millisecond)
    }

  defp ads(conn, method, params, origin \\ "https://frontman.sh") do
    conn
    |> put_req_header("origin", origin)
    |> put_req_header("content-type", "application/json")
    |> dispatch(@endpoint, method, "/ads/attribution", Jason.encode!(params))
  end
end
