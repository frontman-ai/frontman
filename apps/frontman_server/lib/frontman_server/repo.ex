defmodule FrontmanServer.Repo do
  use Ecto.Repo,
    otp_app: :frontman_server,
    adapter: Ecto.Adapters.Postgres
end
