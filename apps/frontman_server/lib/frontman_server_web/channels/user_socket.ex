defmodule FrontmanServerWeb.UserSocket do
  use Phoenix.Socket

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope

  ## Channels
  channel("tasks", FrontmanServerWeb.TasksChannel)
  channel("task:*", FrontmanServerWeb.TaskChannel)

  # Token is valid for 2 weeks (same as session)
  @max_age 14 * 24 * 60 * 60

  @impl true
  def connect(params, socket, connect_info) do
    scope =
      get_scope_from_token(params) ||
        get_scope_from_session(connect_info)

    case scope do
      %Scope{} -> {:ok, assign(socket, :scope, scope)}
      nil -> {:ok, socket}
    end
  end

  # Cross-origin auth: token passed in WebSocket params
  defp get_scope_from_token(%{"token" => token}) do
    case Phoenix.Token.verify(FrontmanServerWeb.Endpoint, "user socket", token, max_age: @max_age) do
      {:ok, user_id} -> Accounts.get_user!(user_id) |> Scope.for_user()
      _ -> nil
    end
  rescue
    Ecto.NoResultsError -> nil
  end

  defp get_scope_from_token(_), do: nil

  # Same-origin auth: session cookie
  defp get_scope_from_session(connect_info) do
    with %{"user_token" => token} <- connect_info[:session],
         {user, _} <- Accounts.get_user_by_session_token(token) do
      Scope.for_user(user)
    else
      _ -> nil
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
