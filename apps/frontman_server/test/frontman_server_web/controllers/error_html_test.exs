defmodule FrontmanServerWeb.ErrorHTMLTest do
  use FrontmanServerWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html with support paths" do
    html = render_to_string(FrontmanServerWeb.ErrorHTML, "404", "html", [])

    assert html =~ "Error 404"
    assert html =~ "Not Found"
    assert html =~ "support@frontman.sh"
    assert html =~ "https://discord.gg/xk8uXJSvhC"
  end

  test "renders 500.html with support paths" do
    html = render_to_string(FrontmanServerWeb.ErrorHTML, "500", "html", [])

    assert html =~ "Error 500"
    assert html =~ "Internal Server Error"
    assert html =~ "mailto:support@frontman.sh?subject=Frontman%20error%20500"
    assert html =~ "https://discord.gg/xk8uXJSvhC"
  end
end
