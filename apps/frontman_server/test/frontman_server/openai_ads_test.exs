defmodule FrontmanServer.OpenAIAdsTest do
  use FrontmanServerWeb.ConnCase, async: false
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Changeset
  alias FrontmanServer.{Accounts, OpenAIAds, Repo, Tasks}
  alias FrontmanServer.OpenAIAds.{CAPI, Consent, DeliverConversion, Delivery}
  alias FrontmanServerWeb.OpenAIAdsCookie

  setup do
    previous = Application.get_env(:frontman_server, OpenAIAds)
    Application.put_env(:frontman_server, OpenAIAds, enabled: true)
    on_exit(fn -> Application.put_env(:frontman_server, OpenAIAds, previous) end)
  end

  test "actual new-user transaction claims registration; login does not" do
    granted = ads(build_conn(), :post, grant())
    assert {granted.params, granted.body_params} == {%{}, %{}}

    conn = %{recycle(granted) | secret_key_base: granted.secret_key_base}
    id = OpenAIAdsCookie.id(conn)
    profile = valid_identity_attributes(%{provider_avatar_url: nil})

    assert {:ok, user} = Accounts.complete_oauth_profile(profile, nil, id)
    assert {:ok, _} = Accounts.complete_oauth_profile(profile, nil, id)
    assert [%Delivery{kind: "registration_completed", status: "pending"}] = Repo.all(Delivery)
    original = Repo.get!(Consent, id)

    params =
      grant() |> Map.put("oppref", nil) |> Map.update!("consent_updated_at_ms", &(&1 + 1000))

    saved = granted |> recycle() |> log_in_user(user) |> ads(:post, params)
    assert saved.status == 204
    assert Repo.get!(Consent, id) == original
    saved |> recycle() |> ads(:post, Map.put(grant(), "oppref", "new click"))
    assert Repo.get!(Consent, id).oppref == "new click"
    assert [%Delivery{status: "pending", oppref: " opaque+/ "}] = Repo.all(Delivery)
    other = user_fixture()
    {token, _} = generate_user_magic_link_token(other)
    fresh = ads(build_conn(), :post, grant())
    fresh |> recycle() |> post("/users/log-in", %{"user" => %{"token" => token}})
    assert Repo.get_by!(Consent, user_id: other.id).oppref == " opaque+/ "
    assert Repo.get!(Consent, id).user_id == user.id
    assert Repo.aggregate(Delivery, :count) == 1
    denied = granted |> recycle() |> ads(:delete, %{})
    assert denied.status == 204
    assert Repo.get!(Consent, id).oppref == nil
    assert (denied |> recycle() |> ads(:post, grant())).status == 204
    assert [%Delivery{status: "suppressed", oppref: nil}] = Repo.all(Delivery)

    assert :ok =
             DeliverConversion.perform(%Oban.Job{
               args: %{"delivery_id" => Repo.one!(Delivery).id}
             })
  end

  @tag :tmp_dir
  test "persisted completion needs a successful edit in the same turn, not reads/errors/cancellation",
       %{tmp_dir: dir} do
    scope = user_scope_fixture()
    task = task_fixture(scope)
    File.write!(Path.join(dir, "read.txt"), "hello")

    for {name, path, outcome} <- [
          {"wp_update_post", "dry_run", :completed},
          {"read_file", "read.txt", :completed},
          {"edit_file", "absent.txt", :completed},
          {"write_file", "cancelled.txt", :cancelled},
          {"write_file", "failed.txt", {:failed, "failed"}},
          {"write_file", "success.txt", :completed}
        ] do
      turn = start_turn_fixture(scope, task.id)
      # Native dry-run payload is persisted input; no HTTP/provider is substituted.
      result =
        case name do
          "wp_update_post" ->
            %{"content" => [%{"type" => "text", "text" => ~s({"dry_run":true})}]}

          _file_tool ->
            file_tool(dir, name, path)
        end

      call = %SwarmAi.ToolCall{id: Ecto.UUID.generate(), name: name, arguments: "{}"}
      assert {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :synchronous)
      assert {:ok, _, :no_executor} = Tasks.resolve_tool_request(scope, task.id, call, result)
      assert Repo.all(Delivery) == []
      assert {:ok, _} = Tasks.record_execution_outcome(scope, task.id, turn, outcome)
      if path == "dry_run", do: refute(Tasks.earlier_edit?(scope.user.id))
    end

    assert [%Delivery{status: "suppressed"} = first] = Repo.all(Delivery)
    assert File.read!(Path.join(dir, "success.txt")) == "hello"
    assert Tasks.earlier_edit?(scope.user.id)
    assert :ok = Tasks.delete_task(scope, task.id)
    granted = build_conn() |> log_in_user(scope.user) |> ads(:post, grant())
    assert granted.status == 204
    :ok = OpenAIAds.record(scope.user.id, "first_successful_edit", "replay")
    assert Repo.one!(Delivery).id == first.id
    assert Repo.one!(Delivery).status == "suppressed"
  end

  test "committed concurrent claims keep one UUID and immutable inputs; disabled worker sends nothing" do
    Sandbox.unboxed_run(Repo, fn ->
      user = user_fixture()

      try do
        {:ok, consent} = OpenAIAds.grant(nil, grant(), nil)
        :ok = OpenAIAds.associate(user.id, consent.id)

        results =
          Task.async_stream(
            1..4,
            fn _ ->
              Sandbox.unboxed_run(Repo, fn ->
                OpenAIAds.record(user.id, "first_successful_edit", "hosted_mcp:wp_update_post")
              end)
            end,
            timeout: 10_000
          )
          |> Enum.to_list()

        assert Enum.all?(results, &(&1 == {:ok, :ok}))
        delivery = Repo.get_by!(Delivery, user_id: user.id)
        :ok = OpenAIAds.record(user.id, delivery.kind, "later")
        assert Repo.get!(Delivery, delivery.id) == delivery
        request = CAPI.request(delivery, "inert-pixel", "inert-header") |> Req.Request.prepare()

        assert request.url.host == "bzr.openai.com"
        assert %{"events" => [event]} = Jason.decode!(request.body)

        # The real adapter validates its pool before Finch rejects this scheme, without HTTP.
        preflight = %{request | url: URI.parse("preflight://adapter-validation")}

        assert_raise ArgumentError,
                     ~s(invalid scheme "preflight" for url: preflight://adapter-validation),
                     fn -> Req.Finch.run(preflight) end

        assert event == %{
                 "id" => delivery.id,
                 "timestamp_ms" => delivery.timestamp_ms,
                 "type" => "custom",
                 "custom_event_name" => "first_successful_edit",
                 "data" => %{"type" => "custom"},
                 "action_source" => "web",
                 "source_url" => "https://frontman.sh/",
                 "opt_out" => true,
                 "oppref" => " opaque+/ "
               }

        assert {:discard, :disabled_or_expired} = CAPI.send(delivery)

        Repo.get!(Consent, consent.id)
        |> Changeset.change(expires_at: DateTime.add(DateTime.utc_now(:second), -1))
        |> Repo.update!()

        assert {:discard, :permission} =
                 DeliverConversion.perform(%Oban.Job{args: %{"delivery_id" => delivery.id}})
      after
        if delivery = Repo.get_by(Delivery, user_id: user.id) do
          Repo.get_by!(Oban.Job, args: %{"delivery_id" => delivery.id}) |> Repo.delete!()
        end

        Repo.delete!(user)
      end
    end)
  end

  defp grant,
    do: %{
      "advertising_consent" => true,
      "oppref" => " opaque+/ ",
      "consent_updated_at_ms" => System.system_time(:millisecond)
    }

  defp ads(conn, method, params) do
    conn
    |> put_req_header("origin", "https://frontman.sh")
    |> put_req_header("content-type", "application/json")
    |> dispatch(@endpoint, method, "/ads/attribution", Jason.encode!(params))
  end

  defp file_tool(dir, name, path) do
    module = name |> String.split("_") |> Enum.map_join(&String.capitalize/1)

    source =
      Path.expand("../../libs/frontman-core/src/tools/FrontmanCore__Tool__#{module}.res.mjs")

    script = """
    const {execute} = await import(process.argv[1]);
    const result = await execute({projectRoot: process.argv[2], sourceRoot: process.argv[2]},
      {path: process.argv[3], content: "hello", oldText: "missing", newText: "next"});
    console.log(JSON.stringify(result));
    """

    {output, 0} = System.cmd("node", ["--input-type=module", "-e", script, source, dir, path])
    Jason.decode!(output)
  end
end
