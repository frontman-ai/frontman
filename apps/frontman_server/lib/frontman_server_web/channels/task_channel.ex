defmodule FrontmanServerWeb.TaskChannel do
  use FrontmanServerWeb, :channel

  @impl true
  def join("task:" <> task_id, _payload, socket) do
    # In Phase 1, we just allow joining any task ID.
    # Later we will verify if the task exists or create it.
    {:ok, assign(socket, :task_id, task_id)}
  end

  @impl true
  def handle_in("message", %{"content" => content}, socket) do
    # Stub response for Phase 1
    response = "Echo: #{content}"
    push(socket, "message", %{content: response, sender: "system"})
    {:reply, :ok, socket}
  end
end
