# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.Fireworks do
  @moduledoc """
  ReqLLM provider for Fireworks' OpenAI-compatible inference API.
  """

  alias LLMDB.Model
  alias ReqLLM.Error.Invalid.Parameter, as: InvalidParameter
  alias ReqLLM.Provider.Defaults, as: ProviderDefaults

  use ReqLLM.Provider,
    id: :fireworks,
    default_base_url: "https://api.fireworks.ai/inference/v1",
    default_env_key: "FIREWORKS_API_KEY"

  use ReqLLM.Provider.Defaults

  @supported_model "accounts/fireworks/routers/kimi-k2p5-turbo"
  @provider_schema []

  @impl ReqLLM.Provider
  def prepare_request(operation, model_spec, input, opts) do
    with {:ok, model} <- ReqLLM.model(model_spec),
         :ok <- validate_model(model) do
      ProviderDefaults.prepare_request(__MODULE__, operation, model, input, opts)
    end
  end

  @impl ReqLLM.Provider
  def attach_stream(model, context, opts, finch_name) do
    with :ok <- validate_model(model) do
      ProviderDefaults.default_attach_stream(__MODULE__, model, context, opts, finch_name)
    end
  end

  defp validate_model(%Model{model: @supported_model}), do: :ok

  defp validate_model(%Model{model: model}) do
    {:error,
     InvalidParameter.exception(
       parameter: "Fireworks Fire Pass only supports #{@supported_model}, got #{model}"
     )}
  end
end
