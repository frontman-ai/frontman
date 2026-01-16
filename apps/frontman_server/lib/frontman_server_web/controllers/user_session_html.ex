defmodule FrontmanServerWeb.UserSessionHTML do
  use FrontmanServerWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:frontman_server, FrontmanServer.Mailer)[:adapter] ==
      Swoosh.Adapters.Local
  end
end
