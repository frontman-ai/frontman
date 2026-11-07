defmodule FrontmanServer.WordPress.Onboarding do
  @moduledoc false

  def steps do
    [
      "Sign in to your WordPress Dashboard as an administrator. Click Plugins, then Add New Plugin. Search for Frontman - AI Website Editor. Click Install Now, then Activate.",
      "In your WordPress Dashboard, find the menu on the left. Click Frontman.",
      "Sign in to Frontman with the same account you connected to your AI assistant.",
      "If you see Connect an AI assistant, click it. Otherwise, click the Settings gear, then General.",
      "In General, click Enable MCP and connect.",
      "Return to your AI assistant and ask: Check my connected WordPress sites."
    ]
  end
end
