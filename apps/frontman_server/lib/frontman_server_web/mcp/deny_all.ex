defmodule FrontmanServerWeb.MCP.DenyAll do
  @moduledoc false
  @behaviour Anubis.Server.Authorization.Validator

  @impl true
  def validate_token(_token, _config), do: {:error, :invalid_token}
end
