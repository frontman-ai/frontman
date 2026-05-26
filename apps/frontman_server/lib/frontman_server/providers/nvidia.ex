# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.Nvidia do
  @moduledoc """
  ReqLLM provider for NVIDIA's OpenAI-compatible NIM API.
  """

  use ReqLLM.Provider,
    id: :nvidia,
    default_base_url: "https://integrate.api.nvidia.com/v1",
    default_env_key: "NVIDIA_API_KEY"

  use ReqLLM.Provider.Defaults

  @provider_schema []
end
