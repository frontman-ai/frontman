defmodule FrontmanServerWeb.WordPressOnboardingController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Billing
  alias FrontmanServer.WordPress
  alias FrontmanServer.WordPress.Onboarding
  alias FrontmanServerWeb.MCP.Server

  def show(conn, _params), do: render_page(conn, nil, nil)

  def verify(conn, params) do
    scope = conn.assigns.current_scope
    sites = WordPress.list_sites(scope)
    site_id = params["site_id"]

    case {Billing.subscription_access(scope), Enum.find(sites, &(&1.id == site_id))} do
      {{:allowed, _}, %{id: id} = site} ->
        result =
          with {:ok, entries} <- WordPress.discover_tools(scope, [id]),
               [_ | _] <- Server.catalog_tools(entries, ["list_sites"]) do
            :verified
          else
            _ -> :failed
          end

        render_page(conn, result, site)

      {{:allowed, _}, nil} ->
        conn |> put_status(:bad_request) |> render_page(:failed, nil)

      {_inactive, _} ->
        render_page(conn, nil, nil)
    end
  end

  defp render_page(conn, result, selected) do
    scope = conn.assigns.current_scope
    access_status = Billing.subscription_access(scope)

    render(conn, :show,
      sites: WordPress.list_sites(scope),
      site_links: WordPress.list_site_links(scope),
      active: match?({:allowed, _}, access_status),
      billing_status: billing_status(access_status),
      result: result,
      selected: selected,
      form: Phoenix.Component.to_form(%{"site_id" => selected && selected.id}),
      page_title: "Connect WordPress to ChatGPT",
      steps: Onboarding.steps()
    )
  end

  defp billing_status({_, status}), do: status
  defp billing_status(:none), do: "none"
end
