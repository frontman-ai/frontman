# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Observability.SentryContext do
  @moduledoc false

  alias FrontmanServer.Accounts.Scope

  def set_task_scope_context(%Scope{} = scope, task_id) when is_binary(task_id) do
    set_scope_context(scope)
    set_task_context(task_id)
  end

  def set_task_scope_context(%Scope{} = scope, _task_id), do: set_scope_context(scope)

  def set_task_scope_context(_scope, _task_id), do: :ok

  def set_scope_context(%Scope{} = scope) do
    Sentry.Context.set_user_context(%{
      id: Scope.user_id(scope),
      email: Scope.user_email(scope),
      username: Scope.user_name(scope)
    })

    Sentry.Context.set_tags_context(%{user_id: Scope.user_id(scope)})
    Logger.metadata(user_id: Scope.user_id(scope), user_name: Scope.user_name(scope))
  end

  def set_scope_context(_scope), do: :ok

  def set_task_context(task_id) when is_binary(task_id) do
    Sentry.Context.set_tags_context(%{task_id: task_id})
    Sentry.Context.set_extra_context(%{task_id: task_id})
    Logger.metadata(task_id: task_id)
  end

  def set_task_context(_task_id), do: :ok
end
