defmodule FrontmanServerWeb.Plugs.SentryContext do
  @moduledoc false

  alias FrontmanServer.Observability.SentryContext

  def init(opts), do: opts

  def call(conn, _opts) do
    conn.assigns[:current_scope]
    |> SentryContext.set_scope_context()

    conn
  end
end
