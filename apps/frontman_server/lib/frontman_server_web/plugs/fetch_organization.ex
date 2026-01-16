defmodule FrontmanServerWeb.Plugs.FetchOrganization do
  @moduledoc """
  Fetches the current organization from the URL path and adds it to the scope.

  This plug extracts the `org_slug` parameter from the URL, verifies the
  scoped user is a member of that organization, and updates `current_scope`
  to include the organization.

  Returns 404 if the organization is not found or user is not a member.
  """

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
