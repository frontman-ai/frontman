defmodule FrontmanServerWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use FrontmanServerWeb.ChannelCase, async: true`,
  although this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import FrontmanServerWeb.ChannelCase

      # The default endpoint for testing
      @endpoint FrontmanServerWeb.Endpoint
    end
  end

  setup tags do
    if tags[:shared_sandbox] && tags[:async] do
      raise "Cannot combine shared_sandbox: true with async: true - shared sandbox requires synchronous execution"
    end

    shared = tags[:shared_sandbox] || not tags[:async]
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: shared)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    # Create a test user for scope
    {:ok, user} =
      Accounts.register_user(%{
        email: "channel_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    {:ok, scope: scope, user: user}
  end
end
