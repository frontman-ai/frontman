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

  @impl true
  def connect(_params, socket, %{auth_token: token}) when is_binary(token) do
    case Accounts.get_scope_by_embedded_client_token(token) do
      {%Scope{} = scope, token_id} when is_binary(token_id) ->
        Accounts.touch_embedded_client_token(token_id)

        {:ok,
         socket
         |> assign(:scope, scope)
         |> assign(:embedded_client_token_id, token_id)}

      nil ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(%{assigns: %{embedded_client_token_id: token_id}}) when is_binary(token_id) do
    "client_token:#{token_id}"
  end

  def id(_socket), do: nil
end
