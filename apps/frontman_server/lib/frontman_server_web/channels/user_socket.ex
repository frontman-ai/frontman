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

  defp get_scope_from_token(%{"token" => token}) do
    case Phoenix.Token.verify(FrontmanServerWeb.Endpoint, "user socket", token, max_age: @max_age) do
      {:ok, user_id} -> Accounts.get_user!(user_id) |> Scope.for_user()
      _ -> nil
    end
  rescue
    Ecto.NoResultsError -> nil
  end

  defp get_scope_from_token(_), do: nil

  defp get_scope_from_session(connect_info) do
    with %{"user_token" => token} <- connect_info[:session],
         {user, _} <- Accounts.get_user_by_session_token(token) do
      Scope.for_user(user)
    else
      _ -> nil
    end
  end

  @impl true
  def id(_socket), do: nil
end
