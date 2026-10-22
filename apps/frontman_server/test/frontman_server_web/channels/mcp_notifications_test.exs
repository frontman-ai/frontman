defmodule FrontmanServerWeb.MCPNotificationsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias FrontmanServer.Protocols.JsonRpc
  alias FrontmanServerWeb.TaskChannel

  test "unopened subscription notifications are logged without replying or changing client state" do
    socket = %Phoenix.Socket{}

    for id <- [1, "1"],
        method <- ["notifications/subscriptions/acknowledged", "notifications/cancelled"] do
      params = %{
        "_meta" => %{"io.modelcontextprotocol/subscriptionId" => id},
        "notifications" => %{},
        "requestId" => id
      }

      log =
        capture_log(fn ->
          assert {:noreply, ^socket} =
                   TaskChannel.handle_in(
                     "mcp:message",
                     JsonRpc.notification(method, params),
                     socket
                   )
        end)

      assert log =~ "Ignoring MCP server notification with no active subscription"
      refute_received %Phoenix.Socket.Message{}
    end
  end
end
