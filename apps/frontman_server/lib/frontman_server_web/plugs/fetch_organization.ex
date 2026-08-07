defmodule FrontmanServerWeb.Plugs.FetchOrganization do
  import Plug.Conn

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Organizations

  def init(opts), do: opts

  def call(%{params: %{"org_slug" => slug}} = conn, _opts) do
    scope = conn.assigns[:current_scope]

    case scope && Organizations.get_organization_by_slug(scope, slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.put_view(FrontmanServerWeb.ErrorHTML)
        |> Phoenix.Controller.render("404.html")
        |> halt()

      organization ->
        updated_scope = Scope.for_user(scope.user, organization)
        assign(conn, :current_scope, updated_scope)
    end
  end

  def call(conn, _opts), do: conn
end
