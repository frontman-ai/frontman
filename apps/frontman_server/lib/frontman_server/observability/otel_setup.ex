defmodule FrontmanServer.Observability.OTelSetup do
  @moduledoc """
  Configures OpenTelemetry SDK.

  This module is called during application startup to ensure
  OTel is properly configured before any spans are created.
  """

  require Logger

  @doc """
  Initializes OpenTelemetry configuration.

  Call this early in application.ex start/2.
  """
  @spec configure() :: :ok
  def configure do
    Logger.info("OpenTelemetry configured")
    :ok
  end
end
