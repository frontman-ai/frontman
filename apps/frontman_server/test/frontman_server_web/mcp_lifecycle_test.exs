defmodule FrontmanServerWeb.MCPLifecycleTest do
  use FrontmanServerWeb.ConnCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Analytics
  alias FrontmanServer.Workers.DeliverHeapEvent

  @issuer "https://issuer.example/tenant"
  @resource "https://resource.example/mcp"
  @cache_key {Anubis.Server.Authorization.JWTValidator, :jwks, @issuer <> "/oauth2/jwks"}

  setup do
    previous = Application.get_env(:frontman_server, Analytics)
    cached = :persistent_term.get(@cache_key, nil)
    key = JOSE.JWK.generate_key({:rsa, 2048})
    {_, public} = JOSE.JWK.to_public_map(key)

    # Exercise the real cached JWKS verifier with real cryptographic keys.
    :persistent_term.put(
      @cache_key,
      {%{"keys" => [Map.put(public, "kid", "lifecycle-test")]}, System.os_time(:second)}
    )

    Application.put_env(:frontman_server, Analytics,
      enabled: true,
      anonymous_enabled: true,
      mcp_clients: %{"verified-client" => "claude"}
    )

    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler,
        [:phoenix, :endpoint, :stop],
        &__MODULE__.request_finished/4,
        self()
      )

    on_exit(fn ->
      :telemetry.detach(handler)

      if previous,
        do: Application.put_env(:frontman_server, Analytics, previous),
        else: Application.delete_env(:frontman_server, Analytics)

      if cached,
        do: :persistent_term.put(@cache_key, cached),
        else: :persistent_term.erase(@cache_key)
    end)

    %{key: key, user: user_fixture()}
  end

  test "real HTTP initialize observes JSON and SSE results without tool activity", context do
    for accept <- ["application/json", "application/json, text/event-stream"] do
      signed =
        token(context, %{"sid" => "private-consent", "jti" => Ecto.UUID.generate()})

      response = wire(signed, initialize(), accept)
      assert response.status == 200
      assert response.headers["mcp-session-id"] != nil
    end

    assert length(events("mcp_initialize_received")) == 2
    assert length(events("mcp_initialize_completed")) == 2
    assert length(events("mcp_client_connected")) == 1
    assert events("mcp_tool_call_completed") == []

    for job <- events("mcp_initialize_completed") do
      assert job.args["identity"] == context.user.id
      assert job.args["properties"]["outcome"] == "succeeded"
      assert job.args["properties"]["mcp_client"] == "claude"
      assert job.args["properties"]["duration_ms"] >= 0
    end

    received_ids =
      Enum.map(events("mcp_initialize_received"), & &1.args["properties"]["request_id"])

    completed_ids =
      Enum.map(events("mcp_initialize_completed"), & &1.args["properties"]["request_id"])

    assert Enum.sort(received_ids) == Enum.sort(completed_ids)

    consent_ids =
      Enum.map(events("mcp_initialize_completed"), & &1.args["properties"]["mcp_connection_id"])

    assert [consent_id] = Enum.uniq(consent_ids)
    assert is_binary(consent_id)
    assert byte_size(consent_id) == 43

    refute Map.has_key?(
             hd(events("mcp_initialize_completed")).args["properties"],
             "onboarding_attempt_id"
           )

    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "private-client-name"
    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "private-consent"
    refute inspect(all_enqueued(worker: DeliverHeapEvent)) =~ "verified-client"
  end

  test "protocol errors are not successful even when sent with HTTP 200", context do
    for accept <- ["application/json", "application/json, text/event-stream"] do
      response =
        wire(
          token(context),
          Map.delete(initialize(), "params"),
          accept
        )

      assert response.status == 200
    end

    assert length(events("mcp_initialize_completed")) == 2

    for job <- events("mcp_initialize_completed") do
      assert job.args["properties"]["outcome"] == "failed"
      assert job.args["properties"]["reason_code"] == "protocol_error"
    end
  end

  test "missing bearer discovery is excluded, malformed bearer diagnostics are anonymous and deduped" do
    assert wire(nil, initialize()).status == 401
    assert events("mcp_authentication_failed") == []

    for _ <- 1..3 do
      assert wire("private-invalid-token", initialize()).status == 401
    end

    [job] = events("mcp_authentication_failed")
    assert job.args["identity"] =~ "mcp_diagnostic:"
    assert job.args["properties"]["identity_kind"] == "unattributed"
    assert job.args["properties"]["reason_code"] == "invalid_token"
    refute Map.has_key?(job.args["properties"], "frontman_user_id")
    refute Map.has_key?(job.args["properties"], "onboarding_attempt_id")
    refute inspect(job) =~ "private-invalid-token"
    assert events("mcp_initialize_received") == []
  end

  test "signed but rejected claims cannot attribute a failure to their user or client", context do
    for {claims, reason} <- [
          {%{"exp" => System.system_time(:second) - 60}, "token_expired"},
          {%{"aud" => "https://wrong.example/mcp"}, "invalid_audience"},
          {%{"iss" => "https://wrong.example"}, "invalid_issuer"},
          {%{"sub" => Ecto.UUID.generate()}, "invalid_token"},
          {%{"nbf" => System.system_time(:second) + 600}, "invalid_token"}
        ] do
      assert wire(token(context, claims), initialize()).status == 401

      assert Enum.any?(events("mcp_authentication_failed"), fn job ->
               job.args["properties"]["reason_code"] == reason
             end)
    end

    assert events("mcp_initialize_received") == []

    for job <- events("mcp_authentication_failed") do
      assert job.args["identity"] =~ "mcp_diagnostic:"
      assert job.args["properties"]["mcp_client"] == "unknown"
      refute inspect(job) =~ context.user.id
      refute inspect(job) =~ "verified-client"
    end
  end

  test "anonymous opt-out prevents rejected-token collection", context do
    Application.put_env(
      :frontman_server,
      Analytics,
      Keyword.put(Analytics.config(), :anonymous_enabled, false)
    )

    assert wire(token(context, %{"aud" => "wrong"}), initialize()).status == 401
    assert events("mcp_authentication_failed") == []
  end

  test "HTTP rejection before MCP authorization does not invent an authenticated initialize",
       context do
    assert wire(token(context), initialize(), "text/plain").status == 406
    assert events("mcp_initialize_received") == []
    assert events("mcp_initialize_completed") == []
  end

  test "wrong signatures never reuse authenticated request identity", context do
    assert wire(token(context), initialize()).status == 200
    rejected = %{context | key: JOSE.JWK.generate_key({:rsa, 2048})}
    assert wire(token(rejected), initialize()).status == 401

    [job] = events("mcp_authentication_failed")
    assert job.args["properties"]["reason_code"] == "invalid_token"
    assert job.args["properties"]["mcp_client"] == "unknown"
    refute inspect(job) =~ context.user.id
    refute Map.has_key?(job.args["properties"], "mcp_connection_id")
    assert length(events("mcp_initialize_received")) == 1
  end

  test "disabled collection leaves authenticated initialization working", context do
    Application.put_env(:frontman_server, Analytics, enabled: false)
    assert wire(token(context), initialize()).status == 200
    assert all_enqueued(worker: DeliverHeapEvent) == []
  end

  test "malformed initialize and non-initialize traffic do not invent successful initialization",
       context do
    assert wire(token(context), %{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"}).status ==
             404

    assert wire(token(context), %{"jsonrpc" => "2.0", "id" => 2, "method" => "initialize"}).status ==
             200

    assert events("mcp_initialize_completed")
           |> Enum.all?(&(&1.args["properties"]["outcome"] != "succeeded"))
  end

  defp initialize do
    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => "2025-06-18",
        "capabilities" => %{},
        "clientInfo" => %{"name" => "private-client-name", "version" => "1.0"}
      }
    }
  end

  defp token(context, overrides \\ %{}) do
    claims =
      Map.merge(
        %{
          "sub" => context.user.id,
          "exp" => System.system_time(:second) + 300,
          "iss" => @issuer,
          "aud" => @resource,
          "client_id" => "verified-client"
        },
        overrides
      )

    {_, signed} =
      context.key
      |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => "lifecycle-test"}, claims)
      |> JOSE.JWS.compact()

    signed
  end

  defp wire(token, body, accept \\ "application/json") do
    {:ok, {_ip, port}} = FrontmanServerWeb.Endpoint.server_info(:http)
    authorization = if token, do: [{"authorization", "Bearer " <> token}], else: []

    response =
      Req.post!("http://127.0.0.1:#{port}/mcp",
        headers: [{"accept", accept} | authorization],
        json: body,
        retry: false,
        receive_timeout: 5_000
      )

    # The socket can deliver bytes before the request's analytics write returns.
    assert_receive :request_finished, 5_000
    response
  end

  def request_finished(_event, _measurements, %{conn: %{request_path: "/mcp"}}, owner),
    do: send(owner, :request_finished)

  def request_finished(_event, _measurements, _metadata, _owner), do: :ok

  defp events(event) do
    Enum.filter(all_enqueued(worker: DeliverHeapEvent), &(&1.args["event"] == event))
  end
end
