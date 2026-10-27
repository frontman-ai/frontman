defmodule FrontmanServer.FirstUseActivation do
  @moduledoc """
  Coordinates the first accepted prompt milestone and its durable activation effect.

  The caller owns the transaction so message acceptance, milestone, and job commit
  or roll back together. The conditional milestone update serializes concurrent
  first prompts; only the transaction that records it inserts an activation job.
  """

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Workers.SyncResendContact

  @doc """
  Records first use within the caller's transaction.

  Repeated calls preserve the milestone and do not enqueue another job.
  Raises outside a transaction or if durable job insertion fails.
  """
  @spec record(Scope.t()) :: :ok
  def record(%Scope{} = scope) do
    unless Repo.in_transaction?() do
      raise ArgumentError, "first-use activation requires the acceptance transaction"
    end

    if Accounts.record_first_message(scope) do
      %{user_id: Accounts.scope_user_id(scope), activation: true}
      |> SyncResendContact.new()
      |> Oban.insert!()
    end

    :ok
  end
end
