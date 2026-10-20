defmodule FrontmanServer.PromptAcceptance do
  @moduledoc """
  Atomically records the first accepted prompt and persists its message.

  The caller supplies persistence so task internals stay private, and publishes
  the accepted message only after this transaction succeeds.
  """

  use Boundary, deps: [FrontmanServer, FrontmanServer.Accounts]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo

  def accept(%Scope{} = scope, persist_message) when is_function(persist_message, 0) do
    Repo.transact(fn ->
      :ok = Accounts.record_first_message(scope)
      persist_message.()
    end)
  end
end
