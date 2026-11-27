defmodule FrontmanServerWeb.MCP.HandoffEvent do
  @moduledoc "The server-side decision recorded at an MCP handoff, before the assistant is known."
  require Logger

  alias FrontmanServer.Observability.MCPHandoff

  def access(scope, stage, {:allowed, _}),
    do: emit(scope, stage, :allowed, :eligible_subscription)

  def access(scope, stage, :none), do: emit(scope, stage, :blocked, :no_subscription)

  def access(scope, stage, {:inactive, _}),
    do: emit(scope, stage, :blocked, :ineligible_subscription)

  def redirected(scope), do: emit(scope, :completion, :redirected, :authorized)
  def authorization_failed(scope), do: emit(scope, :completion, :failed, :authorization_failed)
  def invalid(scope, stage), do: emit(scope, stage, :failed, :invalid_request)

  defp emit(scope, stage, outcome, reason) do
    event = %MCPHandoff{
      stage: stage,
      outcome: outcome,
      reason: reason,
      user_id: scope && scope.user.id
    }

    :telemetry.execute(MCPHandoff.telemetry_name(), %{count: 1}, event)

    Logger.info(
      "MCP handoff stage=#{event.stage} outcome=#{event.outcome} reason=#{event.reason} client=#{event.client}"
    )
  end
end
