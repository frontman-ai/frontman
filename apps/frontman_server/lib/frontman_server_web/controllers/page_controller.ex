defmodule FrontmanServerWeb.PageController do
  use FrontmanServerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
