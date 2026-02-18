defmodule FrontmanServerWeb.UserMeController do
  use FrontmanServerWeb, :controller

  def show(conn, _params) do
    user = conn.assigns.current_scope.user
    json(conn, %{id: user.id, email: user.email, name: user.name})
  end
end
