defmodule SwarmAi.SchemaTransformer do
  @type provider :: :openai_strict | :flexible

  @spec transform(map(), provider()) :: map()
  def transform(schema, :flexible), do: schema
  def transform(schema, :openai_strict), do: transform_for_openai_strict(schema)

  @spec strip_nulls(map()) :: map()
  def strip_nulls(args) when is_map(args) do
    args
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, strip_nulls(v)} end)
  end

  def strip_nulls(value), do: value

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

  defp transform_for_openai_strict(%{"type" => "object", "properties" => properties} = schema) do
    original_required = MapSet.new(Map.get(schema, "required", []))

    transformed_properties =
      Map.new(properties, fn {name, prop_schema} ->
        transformed = transform_nested(prop_schema)

        if MapSet.member?(original_required, name) do
          {name, transformed}
        else
          {name, make_nullable(transformed)}
        end
      end)

    schema
    |> Map.put("properties", transformed_properties)
    |> Map.put("required", Map.keys(properties))
    |> Map.put("additionalProperties", false)
  end

  defp transform_for_openai_strict(schema), do: schema

  defp make_nullable(%{"anyOf" => _} = schema) do
    if has_null_type?(schema) do
      schema
    else
      %{"anyOf" => schema["anyOf"] ++ [%{"type" => "null"}]}
    end
  end

  defp make_nullable(schema) do
    %{"anyOf" => [schema, %{"type" => "null"}]}
  end

  defp has_null_type?(%{"anyOf" => types}) do
    Enum.any?(types, fn
      %{"type" => "null"} -> true
      _ -> false
    end)
  end

  defp transform_nested(%{"type" => "object"} = schema) do
    transform_for_openai_strict(schema)
  end

  defp transform_nested(%{"type" => "array", "items" => items} = schema) do
    Map.put(schema, "items", transform_nested(items))
  end

  defp transform_nested(schema), do: schema
end
