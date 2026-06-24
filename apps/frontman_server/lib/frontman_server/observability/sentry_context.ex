# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Observability.SentryContext do
  @moduledoc false

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Accounts.User

  def set_task_scope_context(%Scope{} = scope, task_id) when is_binary(task_id) do
    set_scope_context(scope)
    set_task_context(task_id)
  end

  def set_task_scope_context(%Scope{} = scope, _task_id), do: set_scope_context(scope)

  def set_task_scope_context(_scope, _task_id), do: :ok

  def set_scope_context(%Scope{user: %User{} = user, organization: organization}) do
    Sentry.Context.set_user_context(%{
      id: user.id,
      email: user.email,
      username: user.name
    })

    extra = %{user_name: user.name}

    extra =
      case organization do
        %{id: organization_id, slug: organization_slug} ->
          Map.merge(extra, %{
            organization_id: organization_id,
            organization_slug: organization_slug
          })

        _ ->
          extra
      end

    Sentry.Context.set_extra_context(extra)
    Sentry.Context.set_tags_context(%{user_id: user.id})

    Logger.metadata(user_id: user.id, user_name: user.name)
  end

  def set_scope_context(_scope), do: :ok

  def set_task_context(task_id) when is_binary(task_id) do
    Sentry.Context.set_tags_context(%{task_id: task_id})
    Sentry.Context.set_extra_context(%{task_id: task_id})
    Logger.metadata(task_id: task_id)
  end

  def set_task_context(_task_id), do: :ok
end
