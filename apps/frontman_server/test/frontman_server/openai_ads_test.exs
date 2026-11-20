defmodule FrontmanServer.OpenAIAdsTest do
  use FrontmanServer.DataCase, async: false
  import FrontmanServer.Test.Fixtures.Accounts
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Changeset
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.OpenAIAds
  alias FrontmanServer.OpenAIAds.{CAPI, Consent, DeliverConversion, Delivery}
  alias FrontmanServer.Repo

  setup do
    previous = Application.get_env(:frontman_server, OpenAIAds)
    Application.put_env(:frontman_server, OpenAIAds, enabled: true)
    on_exit(fn -> Application.put_env(:frontman_server, OpenAIAds, previous) end)
  end

  test "default is inert and a first event without permission cannot replay after opt-in" do
    Application.delete_env(:frontman_server, OpenAIAds)
    refute OpenAIAds.enabled?()
    scope = user_scope_fixture()
    assert Repo.all(Delivery) == []
    :ok = OpenAIAds.record(scope, "registration_completed", scope.user.id)
    assert %Delivery{status: "suppressed"} = original = Repo.one!(Delivery)
    assert Repo.all(Oban.Job) == []
    {:ok, _} = OpenAIAds.grant(scope, nil, grant())
    Application.put_env(:frontman_server, OpenAIAds, enabled: true)
    :ok = OpenAIAds.record(scope, original.kind, "later", fn -> flunk("rescanned") end)
    assert Repo.one!(Delivery) == original
  end

  test "grants preserve same-owner choices; foreign cookies start fresh; denial cannot replay" do
    scope = user_scope_fixture()
    {:ok, original} = OpenAIAds.grant(scope, nil, grant())
    params = Map.put(grant(), "oppref", nil)
    assert {:ok, ^original} = OpenAIAds.grant(scope, original.id, params)
    {:ok, anonymous} = OpenAIAds.grant(%Scope{}, original.id, params)
    assert anonymous.id != original.id
    assert anonymous.oppref == nil
    other = user_scope_fixture()
    {:ok, foreign} = OpenAIAds.grant(other, original.id, params)
    assert foreign.id != original.id
    assert foreign.user_id == other.user.id
    assert foreign.oppref == nil
    assert Repo.get!(Consent, original.id) == original
    :ok = OpenAIAds.record(scope, "first_successful_edit", "one")
    {:ok, _} = OpenAIAds.grant(scope, original.id, Map.put(grant(), "oppref", "new click"))
    assert Repo.one!(Delivery).oppref == " opaque+/ "
    :ok = OpenAIAds.withdraw(scope, original.id)
    assert %Delivery{status: "suppressed", oppref: nil} = Repo.one!(Delivery)
    assert Repo.get!(Consent, original.id).oppref == nil
    {:ok, renewed} = OpenAIAds.grant(scope, original.id, grant())
    assert renewed.id != original.id
    :ok = OpenAIAds.record(scope, "first_successful_edit", "later", fn -> flunk("rescanned") end)
    assert Repo.one!(Delivery).status == "suppressed"
    :ok = OpenAIAds.record(other, "registration_completed", "without permission", fn -> false end)
    assert Repo.get_by!(Delivery, user_id: other.user.id).status == "suppressed"

    assert {:error, :invalid_consent} =
             OpenAIAds.grant(scope, nil, Map.put(grant(), "consent_updated_at_ms", 0))
  end

  test "committed concurrent claims preserve UUID/snapshot and construct the real Req adapter" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        {:ok, consent} = OpenAIAds.grant(%Scope{}, nil, grant())
        :ok = OpenAIAds.associate(scope, consent.id)

        results =
          Task.async_stream(
            1..4,
            fn _ ->
              Sandbox.unboxed_run(Repo, fn ->
                OpenAIAds.record(scope, "first_successful_edit", "hosted_mcp:wp_update_post")
              end)
            end,
            timeout: 10_000
          )
          |> Enum.to_list()

        assert Enum.all?(results, &(&1 == {:ok, :ok}))
        delivery = Repo.get_by!(Delivery, user_id: scope.user.id)
        request = CAPI.request(delivery, "inert-pixel", "inert-header") |> Req.Request.prepare()
        assert request.url.host == "bzr.openai.com"
        assert request.url.path == "/v1/events"
        assert request.url.query == "pid=inert-pixel"
        assert %{"events" => [event]} = Jason.decode!(request.body)
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
        if delivery = Repo.get_by(Delivery, user_id: scope.user.id) do
          Repo.get_by!(Oban.Job, args: %{"delivery_id" => delivery.id}) |> Repo.delete!()
        end

        Repo.delete!(scope.user)
      end
    end)
  end

  defp grant,
    do: %{
      "advertising_consent" => true,
      "oppref" => " opaque+/ ",
      "consent_updated_at_ms" => System.system_time(:millisecond)
    }
end
