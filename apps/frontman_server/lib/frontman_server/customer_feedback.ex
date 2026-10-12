# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.CustomerFeedback do
  @moduledoc "Projects rolling 30-day customer feedback eligibility from task interactions."

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts, FrontmanServer.Tasks]

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.CustomerFeedback.Feedback
  alias FrontmanServer.Repo

  @doc "Whether the user has no request or answer within the rolling cooldown."
  def eligible?(%Scope{} = scope, now \\ DateTime.utc_now()) do
    cutoff = DateTime.add(now, -30, :day)

    scope
    |> Scope.user_id()
    |> Feedback.recent_for_user(cutoff)
    |> Repo.exists?()
    |> Kernel.not()
  end

  def filter_tools(%Scope{} = scope, tools) when is_list(tools) do
    case eligible?(scope) do
      true -> tools
      false -> Enum.reject(tools, &(&1.name == "request_customer_feedback"))
    end
  end
end
