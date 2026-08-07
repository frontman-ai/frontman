defmodule FrontmanServerWeb.ConnCase do
  use ExUnit.CaseTemplate

  alias FrontmanServer.Accounts.Scope

  using do
    quote do
      @endpoint FrontmanServerWeb.Endpoint

      use FrontmanServerWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import FrontmanServerWeb.ConnCase
    end
  end

  setup tags do
    FrontmanServer.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def register_and_log_in_user(%{conn: conn} = context) do
    user = FrontmanServer.Test.Fixtures.Accounts.user_fixture()
    scope = Scope.for_user(user)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  def log_in_user(conn, user, opts \\ []) do
    token = FrontmanServer.Accounts.generate_user_session_token(user)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    FrontmanServer.Test.Fixtures.Accounts.override_token_authenticated_at(token, authenticated_at)
  end
end
