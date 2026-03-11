defmodule FrontmanServer.Providers.Model do
  import Kernel, except: [to_string: 1]

  @moduledoc """
  Typed model reference: provider + model name.

  Replaces the ad-hoc "provider:model" string joining/splitting scattered
  across the codebase. Every place that constructs, parses, or inspects
  a model string should use this struct.

  ## Examples

      iex> model = Model.new("openrouter", "openai/gpt-5.1-codex")
      iex> Model.to_string(model)
      "openrouter:openai/gpt-5.1-codex"

      iex> Model.parse("anthropic:claude-sonnet-4-5")
      {:ok, %Model{provider: "anthropic", name: "claude-sonnet-4-5"}}

      iex> Model.from_client_params(%{"provider" => "openai", "value" => "gpt-5.4"})
      {:ok, %Model{provider: "openai", name: "gpt-5.4"}}
  """

  @type t :: %__MODULE__{
          provider: String.t(),
          name: String.t()
        }

  @enforce_keys [:provider, :name]
  defstruct [:provider, :name]

  @doc """
  Creates a new Model struct.
  """
  @spec new(String.t(), String.t()) :: t()
  def new(provider, name) when is_binary(provider) and is_binary(name) do
    %__MODULE__{provider: provider, name: name}
  end

  @doc """
  Formats a Model as a "provider:name" string for use with ReqLLM/LLMDB.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{provider: provider, name: name}) do
    "#{provider}:#{name}"
  end

  @doc """
  Parses a "provider:name" string into a Model struct.

  Returns `{:ok, model}` on success, `:error` on invalid input.

  ## Examples

      iex> Model.parse("openrouter:openai/gpt-5.1-codex")
      {:ok, %Model{provider: "openrouter", name: "openai/gpt-5.1-codex"}}

      iex> Model.parse("invalid")
      :error
  """
  @spec parse(String.t()) :: {:ok, t()} | :error
  def parse(string) when is_binary(string) do
    case String.split(string, ":", parts: 2) do
      [provider, name] when provider != "" and name != "" ->
        {:ok, new(provider, name)}

      _ ->
        :error
    end
  end

  def parse(_), do: :error

  @doc """
  Parses a "provider:name" string, raising on invalid input.
  """
  @spec parse!(String.t()) :: t()
  def parse!(string) when is_binary(string) do
    case parse(string) do
      {:ok, model} -> model
      :error -> raise ArgumentError, "invalid model string: #{inspect(string)}"
    end
  end

  @doc """
  Extracts the provider from a model string without building a full struct.

  This is the canonical way to determine which provider a model belongs to.
  Falls back to "openrouter" for unprefixed model strings (legacy behaviour).

  ## Examples

      iex> Model.provider_from_string("openrouter:openai/gpt-5.1-codex")
      "openrouter"

      iex> Model.provider_from_string("anthropic:claude-sonnet-4-5")
      "anthropic"

      iex> Model.provider_from_string("some-model-without-prefix")
      "openrouter"
  """
  @spec provider_from_string(String.t()) :: String.t()
  def provider_from_string(string) when is_binary(string) do
    case parse(string) do
      {:ok, model} -> model.provider
      :error -> "openrouter"
    end
  end

  @doc """
  Returns a human-readable display name for any model reference.

  Handles Model structs, plain `"provider:name"` strings, structs with an
  `:id` field (e.g. LLMDB.Model), and nil. Used for span names, log lines,
  and anywhere a model needs to be shown as text.

  ## Examples

      iex> Model.display_name(Model.new("openai", "gpt-5"))
      "openai:gpt-5"

      iex> Model.display_name("anthropic:claude-sonnet-4-5")
      "anthropic:claude-sonnet-4-5"

      iex> Model.display_name(nil)
      "unknown"
  """
  @spec display_name(t() | String.t() | map() | nil) :: String.t()
  def display_name(%__MODULE__{} = model), do: __MODULE__.to_string(model)
  def display_name(model) when is_binary(model), do: model
  def display_name(%{id: id}) when is_binary(id), do: id
  def display_name(nil), do: "unknown"
  def display_name(other), do: inspect(other)

  @doc """
  Extracts the provider name from any model reference.

  Accepts Model structs, `"provider:name"` strings, and structs with an
  atom `:provider` field. Falls back to `"unknown"` for unrecognised shapes.

  ## Examples

      iex> Model.provider_name(Model.new("openai", "gpt-5"))
      "openai"

      iex> Model.provider_name("anthropic:claude-sonnet-4-5")
      "anthropic"

      iex> Model.provider_name(nil)
      "unknown"
  """
  @spec provider_name(t() | String.t() | map() | nil) :: String.t()
  def provider_name(%__MODULE__{provider: p}), do: p

  def provider_name(model) when is_binary(model) do
    case parse(model) do
      {:ok, parsed} -> parsed.provider
      :error -> "unknown"
    end
  end

  def provider_name(%{provider: provider}) when is_atom(provider), do: Atom.to_string(provider)
  def provider_name(_), do: "unknown"

  @doc """
  Extracts the underlying LLM vendor from any model reference.

  For routing proxies like OpenRouter, the vendor is extracted from the
  model name (e.g. `"openrouter:anthropic/claude-opus-4.6"` → `"anthropic"`).
  For direct providers (e.g. `"anthropic:claude-sonnet-4-5"`), the vendor is
  the provider itself. Falls back to `"unknown"` for unrecognised shapes.

  This is the correct value for the `llm.system` OpenTelemetry attribute
  (OpenInference convention), where the attribute should identify the actual
  LLM system, not the routing proxy.

  ## Examples

      iex> Model.llm_vendor_name("openrouter:anthropic/claude-opus-4.6")
      "anthropic"

      iex> Model.llm_vendor_name("openrouter:openai/gpt-5.1-codex")
      "openai"

      iex> Model.llm_vendor_name("anthropic:claude-sonnet-4-5")
      "anthropic"

      iex> Model.llm_vendor_name(nil)
      "unknown"
  """
  @spec llm_vendor_name(t() | String.t() | map() | nil) :: String.t()
  def llm_vendor_name(%__MODULE__{provider: "openrouter", name: name}) do
    extract_vendor_from_name(name)
  end

  def llm_vendor_name(%__MODULE__{provider: p}), do: p

  def llm_vendor_name(model) when is_binary(model) do
    case parse(model) do
      {:ok, parsed} -> llm_vendor_name(parsed)
      :error -> "unknown"
    end
  end

  def llm_vendor_name(%{provider: provider, id: id})
      when is_atom(provider) and provider == :openrouter do
    id_string = if is_atom(id), do: Atom.to_string(id), else: id
    extract_vendor_from_name(id_string)
  end

  def llm_vendor_name(%{provider: provider}) when is_atom(provider), do: Atom.to_string(provider)
  def llm_vendor_name(_), do: "unknown"

  # Extracts vendor from OpenRouter's "vendor/model-name" format.
  # E.g. "anthropic/claude-opus-4.6" → "anthropic"
  defp extract_vendor_from_name(name) when is_binary(name) do
    case String.split(name, "/", parts: 2) do
      [vendor, _rest] when vendor != "" -> vendor
      _ -> "unknown"
    end
  end

  @doc """
  Converts a client-sent model selection map to a Model struct.

  Accepts both string-keyed maps (from JSON/client wire format) and
  atom-keyed maps (from internal Elixir code):

      %{"provider" => "openrouter", "value" => "openai/gpt-5.1-codex"}
      %{provider: "openrouter", value: "openai/gpt-5.1-codex"}

  Returns `{:ok, model}` or `:error`.
  """
  @spec from_client_params(map() | nil) :: {:ok, t()} | :error
  def from_client_params(%{"provider" => provider, "value" => value})
      when is_binary(provider) and is_binary(value) and provider != "" and value != "" do
    {:ok, new(provider, value)}
  end

  def from_client_params(%{provider: provider, value: value})
      when is_binary(provider) and is_binary(value) and provider != "" and value != "" do
    {:ok, new(provider, value)}
  end

  def from_client_params(_), do: :error

  @doc """
  Tries to extract a "provider:name" string from a model selection.

  Accepts a Model struct, a client params map (string or atom keys),
  or nil/other. Returns the formatted string on success, `nil` otherwise.

  Callers apply their own fallback policy (e.g. `|| @fallback_model`).

  ## Examples

      iex> Model.resolve_string(Model.new("openai", "gpt-5"))
      "openai:gpt-5"

      iex> Model.resolve_string(%{"provider" => "openai", "value" => "gpt-5"})
      "openai:gpt-5"

      iex> Model.resolve_string(nil)
      nil
  """
  @spec resolve_string(t() | map() | nil) :: String.t() | nil
  def resolve_string(%__MODULE__{} = model), do: __MODULE__.to_string(model)

  def resolve_string(params) when is_map(params) do
    case from_client_params(params) do
      {:ok, model} -> __MODULE__.to_string(model)
      :error -> nil
    end
  end

  def resolve_string(_), do: nil

  @doc """
  Converts a Model to the client-facing map format.
  """
  @spec to_client_params(t()) :: %{provider: String.t(), value: String.t()}
  def to_client_params(%__MODULE__{provider: provider, name: name}) do
    %{provider: provider, value: name}
  end
end

defimpl String.Chars, for: FrontmanServer.Providers.Model do
  def to_string(model), do: FrontmanServer.Providers.Model.to_string(model)
end

defimpl Inspect, for: FrontmanServer.Providers.Model do
  def inspect(model, _opts) do
    "#Model<#{FrontmanServer.Providers.Model.to_string(model)}>"
  end
end
