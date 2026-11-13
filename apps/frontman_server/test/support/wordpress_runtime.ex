defmodule FrontmanServerWeb.WordPressRuntime do
  alias Ecto.Adapters.SQL.Sandbox

  def init(owner), do: owner

  def call(conn, owner) do
    true = Sandbox.allow(FrontmanServer.Repo, owner, self()) in [:ok, {:already, :allowed}]

    FrontmanServerWeb.Endpoint.call(conn, FrontmanServerWeb.Endpoint.init([]))
  end

  def attach(request) do
    fixture = URI.parse(System.fetch_env!("FRONTMAN_WP_RUNTIME_URL"))
    origin = [:scheme, :host, :port]
    ca = String.to_charlist(System.fetch_env!("FRONTMAN_WP_RUNTIME_CA"))

    Req.Request.append_request_steps(request,
      wordpress_runtime: fn request ->
        if Map.take(request.url, origin) == Map.take(fixture, origin) do
          Req.Request.merge_options(request, connect_options: [transport_opts: [cacertfile: ca]])
        else
          FrontmanServer.PublicURL.protect_req(request)
        end
      end
    )
  end
end
