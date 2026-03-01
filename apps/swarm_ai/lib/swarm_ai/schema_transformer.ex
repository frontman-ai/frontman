defmodule SwarmAi.SchemaTransformer do
  @moduledoc """
  Transforms tool parameter schemas for different LLM providers.

  Different providers have different requirements for tool schemas:
  - OpenAI (strict mode): Requires all properties in `required` array,
    uses nullable types for optional fields, requires `additionalProperties: false`
  - Anthropic/Google/Others: Flexible schemas, optional properties can be omitted

  ## OpenAI Structured Outputs Requirements

  OpenAI's strict mode has specific requirements:
  - `additionalProperties: false` on all object types
  - ALL fields must be in `required` array (no optional fields allowed)
  - To make a field semantically "optional", use nullable types:
    `anyOf: [{"type": "actual_type"}, {"type": "null"}]`
  - Model will always provide every field, but nullable ones can be `null`

  ## Example

      iex> schema = %{
      ...>   "type" => "object",
      ...>   "properties" => %{
      ...>     "name" => %{"type" => "string"},
      ...>     "age" => %{"type" => "integer"}
      ...>   },
      ...>   "required" => ["name"]
      ...> }
      iex> SwarmAi.SchemaTransformer.transform(schema, :openai_strict)
      %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"anyOf" => [%{"type" => "integer"}, %{"type" => "null"}]}
        },
        "required" => ["name", "age"],
        "additionalProperties" => false
      }
  """

  @type provider :: :openai_strict | :flexible

  @doc """
  Transforms a schema for the target provider.

  For `:flexible` providers (Anthropic, Google, etc.), returns schema unchanged.
  For `:openai_strict`, normalizes schema for OpenAI's structured outputs requirements.
  """
  @spec transform(map(), provider()) :: map()
  def transform(schema, :flexible), do: schema
  def transform(schema, :openai_strict), do: transform_for_openai_strict(schema)

  @doc """
  Strips null values from tool call arguments.

  This is the inverse of the strict mode transformation: `transform/2` makes optional
  fields nullable so the model can provide `null`, and `strip_nulls/1` removes those
  nulls before passing arguments to tools that expect missing keys rather than null values.

  Recursively strips null values from nested objects.
  """
  @spec strip_nulls(map()) :: map()
  def strip_nulls(args) when is_map(args) do
    args
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, strip_nulls(v)} end)
  end

  def strip_nulls(value), do: value

  @doc """
  Determines the provider type from a model identifier string.

  Model strings follow the format `"provider:model_name"` or `"provider:org/model_name"`.
  Returns `:openai_strict` for OpenAI and Azure models (via OpenRouter or direct),
  `:flexible` for all others.
  """
  @spec provider_for_model(String.t() | %{provider: atom()}) :: provider()
  def provider_for_model(model) when is_binary(model) do
    if openai_model?(model), do: :openai_strict, else: :flexible
  end

  def provider_for_model(%{provider: provider}) when provider in [:openai, :azure] do
    :openai_strict
  end

  def provider_for_model(%{provider: _}) do
    :flexible
  end

  defp openai_model?(model) do
    String.contains?(model, "openai/") or
      String.contains?(model, "azure/") or
      String.starts_with?(model, "openai:")
  end

  # Transform object schema for OpenAI strict mode
  defp transform_for_openai_strict(%{"type" => "object", "properties" => properties} = schema) do
    original_required = MapSet.new(Map.get(schema, "required", []))

    transformed_properties =
      Map.new(properties, fn {name, prop_schema} ->
        transformed = transform_nested(prop_schema)

        if MapSet.member?(original_required, name) do
          # Required property - keep as-is (but recursively transform nested objects)
          {name, transformed}
        else
          # Optional property - make nullable so model can provide null
          {name, make_nullable(transformed)}
        end
      end)

    schema
    |> Map.put("properties", transformed_properties)
    |> Map.put("required", Map.keys(properties))
    |> Map.put("additionalProperties", false)
  end

  # Pass through non-object schemas unchanged
  defp transform_for_openai_strict(schema), do: schema

  # Wrap a property schema in anyOf with null to make it nullable
  defp make_nullable(%{"anyOf" => _} = schema) do
    # Already has anyOf - check if null is already included
    if has_null_type?(schema) do
      schema
    else
      %{"anyOf" => schema["anyOf"] ++ [%{"type" => "null"}]}
    end
  end

  defp make_nullable(schema) do
    %{"anyOf" => [schema, %{"type" => "null"}]}
  end

  # Check if anyOf already includes a null type
  defp has_null_type?(%{"anyOf" => types}) do
    Enum.any?(types, fn
      %{"type" => "null"} -> true
      _ -> false
    end)
  end

  # Recursively transform nested object schemas
  defp transform_nested(%{"type" => "object"} = schema) do
    transform_for_openai_strict(schema)
  end

  # Transform array items if they contain objects
  defp transform_nested(%{"type" => "array", "items" => items} = schema) do
    Map.put(schema, "items", transform_nested(items))
  end

  # Pass through primitive types unchanged
  defp transform_nested(schema), do: schema
end
