# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.UserSocket do
  use Phoenix.Socket

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope

  channel "tasks", FrontmanServerWeb.TasksChannel
  channel "task:*", FrontmanServerWeb.TaskChannel

  @max_age 5 * 60

  @impl true
  def connect(params, socket, connect_info) do
    authenticated_session =
      get_scope_from_token(params) ||
        get_scope_from_session(connect_info)

    case authenticated_session do
      {%Scope{} = scope, session_id, user_token_id} ->
        {:ok,
         socket
         |> assign(:scope, scope)
         |> assign(:session_id, session_id)
         |> assign(:user_token_id, user_token_id)}

      nil ->
        {:ok, socket}
    end
  end

  defp get_scope_from_token(%{"token" => token}) do
    case Phoenix.Token.verify(FrontmanServerWeb.Endpoint, "user socket", token, max_age: @max_age) do
      {:ok, {user_id, token_id, browser_session_id}} ->
        case Accounts.get_user_by_socket_session(user_id, token_id) do
          nil -> nil
          user -> {Scope.for_user(user), browser_session_id, token_id}
        end

      _ ->
        nil
    end
  end

  defp get_scope_from_token(_), do: nil

  defp get_scope_from_session(connect_info) do
    with %{"user_token" => token} <- connect_info[:session],
         browser_session_id when is_binary(browser_session_id) <-
           connect_info[:session]["socket_session_id"],
         {user, user_token_id} <- Accounts.get_socket_session(token) do
      {Scope.for_user(user), browser_session_id, user_token_id}
    else
      _ -> nil
    end
  end

  @impl true
  def id(%{assigns: %{session_id: session_id}}), do: session_socket_id(session_id)
  def id(_socket), do: nil

  @spec session_socket_id(binary()) :: binary()
  def session_socket_id(session_id) when is_binary(session_id),
    do: "user_sessions:#{session_id}"
end
