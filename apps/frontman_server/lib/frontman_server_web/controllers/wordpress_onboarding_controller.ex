defmodule FrontmanServerWeb.WordPressOnboardingController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.WordPress
  alias FrontmanServer.WordPress.Onboarding

  def show(conn, params) do
    render(conn, :show,
      sites: WordPress.list_sites(conn.assigns.current_scope),
      checked: params["check"] == "1",
      check_form: Phoenix.Component.to_form(%{"check" => "1"}),
      steps: Onboarding.steps()
    )
  end
end
