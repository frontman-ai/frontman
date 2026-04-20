defmodule FrontmanServerWeb.SandboxPreviewSocketTest do
  use ExUnit.Case, async: true

  alias FrontmanServerWeb.SandboxPreviewSocket

  test "returns stop tuple with state when upstream connection fails" do
    state = %{
      upstream_host: "127.0.0.1",
      upstream_port: free_port(),
      upstream_path: "/hmr",
      upstream_query: "",
      upstream_headers: [],
      connect_timeout_ms: 50,
      upgrade_timeout_ms: 50
    }

    assert {:stop, _reason, %SandboxPreviewSocket{}} = SandboxPreviewSocket.init(state)
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
