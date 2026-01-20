defmodule FrontmanServer.Providers.ResolvedKey do
  @moduledoc """
  Represents a resolved API key ready for use in LLM calls.

  This struct is created by `Providers.prepare_api_key/3` at the domain layer
  and passed through to agents and tools. It encapsulates all the information
  needed to make LLM calls and track usage.

  ## Fields

  - `:provider` - Provider name (e.g., "openrouter", "anthropic")
  - `:api_key` - The resolved API key value
  - `:key_source` - Where the key came from (`:user_key`, `:env_key`, `:server_key`)
  - `:model` - The full model string (e.g., "openrouter:openai/gpt-4")
  """

  use TypedStruct

  @type key_source :: :user_key | :env_key | :server_key

  typedstruct enforce: true do
    field(:provider, String.t())
    field(:api_key, String.t())
    field(:key_source, key_source())
    field(:model, String.t())
  end

  @doc """
  Creates a new ResolvedKey struct.
  """
  def new(provider, api_key, key_source, model) do
    %__MODULE__{
      provider: provider,
      api_key: api_key,
      key_source: key_source,
      model: model
    }
  end
end
