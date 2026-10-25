defmodule FrontmanServer.Providers.CodexDiscoveryTimeoutTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.Providers.OpenAIOAuth

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.fetch_env!(:frontman_server, OpenAIOAuth)
    on_exit(fn -> Application.put_env(:frontman_server, OpenAIOAuth, previous) end)
    :ok
  end

  test "discovery bounds total response time and pool waiting by default" do
    plugin = fn request ->
      Req.Request.append_request_steps(request,
        assert_timeouts: fn request ->
          assert request.options[:request_timeout] == 5_000
          assert request.options[:finch][:pool_timeout] == 1_000
          assert request.options[:retry] == false
          assert request.options[:redirect] == false
          request
        end
      )
    end

    Req.Test.expect(:openai_oauth, &Req.Test.json(&1, %{"models" => []}))

    Application.put_env(:frontman_server, OpenAIOAuth,
      req_options: [plug: {Req.Test, :openai_oauth}, plugins: [plugin]]
    )

    assert {:ok, ids} = OpenAIOAuth.available_model_ids("test-token", "test-account")
    assert MapSet.size(ids) == 0
  end

  test "continuous response chunks cannot bypass the total deadline" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_ip, port}} = :inet.sockname(listener)
    on_exit(fn -> :gen_tcp.close(listener) end)
    parent = self()

    {server, monitor} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, 1_000)
        {:ok, _request} = :gen_tcp.recv(socket, 0, 1_000)

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ntransfer-encoding: chunked\r\n\r\n"
          )

        send(parent, :response_started)

        Enum.reduce_while(1..20, :ok, fn _, :ok ->
          Process.sleep(30)

          case :gen_tcp.send(socket, "1\r\n \r\n") do
            :ok -> {:cont, :ok}
            {:error, _closed} -> {:halt, :ok}
          end
        end)

        :gen_tcp.close(socket)
      end)

    Application.put_env(:frontman_server, OpenAIOAuth,
      req_options: [
        url: "http://localhost:#{port}/models",
        request_timeout: 150,
        receive_timeout: 100
      ]
    )

    started_at = System.monotonic_time(:millisecond)

    assert {:error, :model_discovery_failed} =
             OpenAIOAuth.available_model_ids("test-token", "test-account")

    assert_received :response_started
    assert System.monotonic_time(:millisecond) - started_at < 600
    assert_receive {:DOWN, ^monitor, :process, ^server, :normal}, 1_000
  end
end
