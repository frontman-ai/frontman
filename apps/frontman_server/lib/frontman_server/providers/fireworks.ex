# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.Fireworks do
  @moduledoc """
  ReqLLM provider for Fireworks' OpenAI-compatible inference API.
  """

  use ReqLLM.Provider,
    id: :fireworks,
    default_base_url: "https://api.fireworks.ai/inference/v1",
    default_env_key: "FIREWORKS_API_KEY"

  use ReqLLM.Provider.Defaults

  @provider_schema []
end
