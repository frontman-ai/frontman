defmodule FrontmanServerWeb.TaskChannelTest do
  use FrontmanServerWeb.ChannelCase

  alias FrontmanServerWeb.TaskChannel

  setup do
    {:ok, _, socket} =
      FrontmanServerWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(TaskChannel, "task:123")

    %{socket: socket}
  end

  test "echoes messages", %{socket: socket} do
    ref = push(socket, "message", %{"content" => "hello"})
    assert_reply(ref, :ok)

    assert_push("message", %{content: "Echo: hello", sender: "system"})
  end
end
