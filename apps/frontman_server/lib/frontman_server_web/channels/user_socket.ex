defmodule FrontmanServerWeb.UserSocket do
  use Phoenix.Socket

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope

  ## Channels
  channel("tasks", FrontmanServerWeb.TasksChannel)
  channel("task:*", FrontmanServerWeb.TaskChannel)

  @impl true
  def connect(_params, socket, _connect_info) do
    case Accounts.get_user_by_email("dev@frontman.local") do
      nil ->
        {:error, :no_dev_user}

      user ->
        scope = Scope.for_user(user)
        {:ok, assign(socket, :scope, scope)}
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.FrontmanServerWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end
