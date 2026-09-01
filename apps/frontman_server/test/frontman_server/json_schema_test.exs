defmodule FrontmanServer.JSONSchemaTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.JSONSchema

  test "defaults to JSON Schema 2020-12 and validates every JSON root type" do
    vectors = [
      {%{"type" => "object"}, %{}},
      {%{"type" => "array"}, []},
      {%{"type" => "string"}, "value"},
      {%{"type" => "number"}, 1.5},
      {%{"type" => "boolean"}, true},
      {%{"type" => "null"}, nil}
    ]

    for {schema, value} <- vectors do
      assert :ok = JSONSchema.validate_schema(schema)
      assert :ok = JSONSchema.validate(schema, value)
    end
  end

  test "supports local references and rejects nonmatching values" do
    schema = %{
      "$defs" => %{"answer" => %{"type" => "integer"}},
      "$ref" => "#/$defs/answer"
    }

    assert :ok = JSONSchema.validate(schema, 42)
    assert {:error, :validation_failed} = JSONSchema.validate(schema, "42")
  end

  test "rejects unsupported dialects and every external reference scheme" do
    assert {:error, :unsupported_dialect} =
             JSONSchema.validate_schema(%{
               "$schema" => "http://json-schema.org/draft-07/schema#"
             })

    for reference <- [
          "https://127.0.0.1/schema",
          "http://169.254.169.254/schema",
          "file:///tmp/schema.json",
          "data:application/schema+json,{}",
          "other.json#/$defs/value"
        ] do
      assert {:error, :invalid_schema} =
               JSONSchema.validate_schema(%{"$ref" => reference})

      assert {:error, :invalid_schema} =
               JSONSchema.validate_schema(%{"$dynamicRef" => reference})
    end
  end

  test "rejects unsupported nested dialect changes" do
    assert {:error, :unsupported_dialect} =
             JSONSchema.validate_schema(%{
               "$defs" => %{
                 "legacy" => %{"$schema" => "http://json-schema.org/draft-07/schema#"}
               }
             })
  end

  test "does not interpret annotation values as schema locations" do
    for value <- [
          %{"$schema" => "literal"},
          %{"$ref" => "literal"},
          %{"$dynamicRef" => "literal"}
        ] do
      schema = %{"const" => value}
      assert :ok = JSONSchema.validate_schema(schema)
      assert :ok = JSONSchema.validate(schema, value)
    end
  end

  test "enforces exact schema depth and container limits" do
    at_depth = nested_schema(15)
    over_depth = nested_schema(16)
    at_containers = %{"allOf" => List.duplicate(%{}, 1_022)}
    over_containers = %{"allOf" => List.duplicate(%{}, 1_023)}

    assert :ok = JSONSchema.validate_schema(at_depth)
    assert {:error, :schema_depth_exceeded} = JSONSchema.validate_schema(over_depth)
    assert :ok = JSONSchema.validate_schema(at_containers)

    assert {:error, :schema_container_limit_exceeded} =
             JSONSchema.validate_schema(over_containers)
  end

  test "accepts validation completion at 100 ms and rejects it at 101 ms" do
    assert JSONSchema.validation_duration(100) == :accepted
    assert JSONSchema.validation_duration(101) == :timed_out
  end

  test "kills an isolated validation operation after the timeout" do
    assert {:error, :validation_timed_out} = JSONSchema.validation_timeout_probe(1_000, self())
    assert_receive {:validation_probe, pid}
    refute Process.alive?(pid)
    refute_receive {:validation_probe_completed, ^pid}
  end

  defp nested_schema(0), do: %{"type" => "string"}
  defp nested_schema(depth), do: %{"allOf" => [nested_schema(depth - 1)]}
end
