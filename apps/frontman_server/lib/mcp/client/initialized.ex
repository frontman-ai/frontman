defmodule MCP.Client.Initialized do
  @moduledoc false
  # Internal client module for initialized notification.

  @doc """
  Create an initialized notification.

  Send this after successfully receiving the initialize response.
  """
  @spec notify() :: {:ok, map()}
  def notify do
    MCP.Client.notify("notifications/initialized")
  end
end
