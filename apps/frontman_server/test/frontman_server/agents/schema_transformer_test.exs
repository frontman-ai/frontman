defmodule FrontmanServer.Agents.SchemaTransformerTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.SchemaTransformer

  describe "provider_for_model/1" do
    test "returns :openai_strict for OpenAI direct" do
      assert SchemaTransformer.provider_for_model("openai:gpt-4") == :openai_strict
      assert SchemaTransformer.provider_for_model("openai:gpt-4o") == :openai_strict
    end

    test "returns :openai_strict for OpenRouter OpenAI models" do
      assert SchemaTransformer.provider_for_model("openrouter:openai/gpt-4") == :openai_strict
      assert SchemaTransformer.provider_for_model("openrouter:openai/gpt-4o") == :openai_strict
    end

    test "returns :openai_strict for Azure models" do
      assert SchemaTransformer.provider_for_model("openrouter:azure/gpt-4") == :openai_strict
    end

    test "returns :flexible for Anthropic" do
      assert SchemaTransformer.provider_for_model("anthropic:claude-3-opus") == :flexible

      assert SchemaTransformer.provider_for_model("openrouter:anthropic/claude-3-opus") ==
               :flexible
    end

    test "returns :flexible for Google" do
      assert SchemaTransformer.provider_for_model("google:gemini-pro") == :flexible
      assert SchemaTransformer.provider_for_model("openrouter:google/gemini-pro") == :flexible
    end

    test "returns :flexible for other models" do
      assert SchemaTransformer.provider_for_model("openrouter:meta-llama/llama-3") == :flexible

      assert SchemaTransformer.provider_for_model("openrouter:mistralai/mistral-large") ==
               :flexible
    end

    test "returns :openai_strict for LLMDB.Model struct with :openai provider" do
      model = %{provider: :openai, model: "gpt-5.1-codex-max", id: "gpt-5.1-codex-max"}
      assert SchemaTransformer.provider_for_model(model) == :openai_strict
    end

    test "returns :openai_strict for LLMDB.Model struct with :azure provider" do
      model = %{provider: :azure, model: "gpt-4", id: "gpt-4"}
      assert SchemaTransformer.provider_for_model(model) == :openai_strict
    end

    test "returns :flexible for LLMDB.Model struct with :anthropic provider" do
      model = %{provider: :anthropic, model: "claude-3-opus", id: "claude-3-opus"}
      assert SchemaTransformer.provider_for_model(model) == :flexible
    end

    test "returns :flexible for LLMDB.Model struct with :google provider" do
      model = %{provider: :google, model: "gemini-pro", id: "gemini-pro"}
      assert SchemaTransformer.provider_for_model(model) == :flexible
    end
  end

  describe "strip_nulls/1" do
    test "removes top-level null values" do
      args = %{"selector" => nil, "timeout" => 5000}
      assert SchemaTransformer.strip_nulls(args) == %{"timeout" => 5000}
    end

    test "removes multiple null values" do
      args = %{"a" => nil, "b" => nil, "c" => "keep"}
      assert SchemaTransformer.strip_nulls(args) == %{"c" => "keep"}
    end

    test "recursively strips nulls from nested objects" do
      args = %{
        "config" => %{"name" => "test", "optional" => nil},
        "selector" => nil,
        "timeout" => 5000
      }

      assert SchemaTransformer.strip_nulls(args) == %{
               "config" => %{"name" => "test"},
               "timeout" => 5000
             }
    end

    test "returns empty map when all values are null" do
      args = %{"a" => nil, "b" => nil}
      assert SchemaTransformer.strip_nulls(args) == %{}
    end

    test "returns map unchanged when no nulls" do
      args = %{"name" => "test", "count" => 42}
      assert SchemaTransformer.strip_nulls(args) == args
    end

    test "passes through non-map values unchanged" do
      assert SchemaTransformer.strip_nulls("string") == "string"
      assert SchemaTransformer.strip_nulls(42) == 42
      assert SchemaTransformer.strip_nulls(nil) == nil
    end
  end

  describe "transform/2 with :flexible" do
    test "returns schema unchanged" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      assert SchemaTransformer.transform(schema, :flexible) == schema
    end
  end

  describe "transform/2 with :openai_strict" do
    test "adds additionalProperties: false" do
      schema = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}},
        "required" => ["name"]
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      assert result["additionalProperties"] == false
    end

    test "makes all properties required" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      assert Enum.sort(result["required"]) == ["age", "name"]
    end

    test "makes optional properties nullable" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "required_field" => %{"type" => "string"},
          "optional_field" => %{"type" => "string"}
        },
        "required" => ["required_field"]
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      # Required field unchanged
      assert result["properties"]["required_field"] == %{"type" => "string"}

      # Optional field is now nullable
      assert result["properties"]["optional_field"] == %{
               "anyOf" => [%{"type" => "string"}, %{"type" => "null"}]
             }
    end

    test "preserves enum and other constraints when making nullable" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "status" => %{
            "type" => "string",
            "enum" => ["pending", "in_progress", "completed"],
            "default" => "pending"
          }
        },
        "required" => []
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      # Status should be nullable with original constraints preserved
      assert result["properties"]["status"] == %{
               "anyOf" => [
                 %{
                   "type" => "string",
                   "enum" => ["pending", "in_progress", "completed"],
                   "default" => "pending"
                 },
                 %{"type" => "null"}
               ]
             }
    end

    test "does not double-wrap already nullable properties" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "nullable_field" => %{
            "anyOf" => [%{"type" => "string"}, %{"type" => "null"}]
          }
        },
        "required" => []
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      # Should not add another null type
      assert result["properties"]["nullable_field"] == %{
               "anyOf" => [%{"type" => "string"}, %{"type" => "null"}]
             }
    end

    test "handles empty required array (all properties optional)" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "field1" => %{"type" => "string"},
          "field2" => %{"type" => "integer"}
        },
        "required" => []
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      # Both fields should be nullable
      assert match?(%{"anyOf" => _}, result["properties"]["field1"])
      assert match?(%{"anyOf" => _}, result["properties"]["field2"])
    end

    test "handles schema without required array (all properties optional)" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "field1" => %{"type" => "string"}
        }
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      # Field should be nullable
      assert match?(%{"anyOf" => _}, result["properties"]["field1"])
      # Required array should be added
      assert result["required"] == ["field1"]
    end

    test "recursively transforms nested objects" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "user" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "email" => %{"type" => "string"}
            },
            "required" => ["name"]
          }
        },
        "required" => ["user"]
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      # Nested object should also have additionalProperties: false
      assert result["properties"]["user"]["additionalProperties"] == false
      # Nested email (optional) should be nullable
      assert match?(%{"anyOf" => _}, result["properties"]["user"]["properties"]["email"])
      # Nested name (required) should not be nullable
      assert result["properties"]["user"]["properties"]["name"] == %{"type" => "string"}
    end

    test "transforms array items that are objects" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "items" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "id" => %{"type" => "string"},
                "value" => %{"type" => "string"}
              },
              "required" => ["id"]
            }
          }
        },
        "required" => ["items"]
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      # Array items object should be transformed
      items_schema = result["properties"]["items"]["items"]
      assert items_schema["additionalProperties"] == false
      assert items_schema["properties"]["id"] == %{"type" => "string"}
      assert match?(%{"anyOf" => _}, items_schema["properties"]["value"])
    end

    test "passes through non-object schemas unchanged" do
      schema = %{"type" => "string"}
      assert SchemaTransformer.transform(schema, :openai_strict) == schema

      array_schema = %{"type" => "array", "items" => %{"type" => "string"}}
      assert SchemaTransformer.transform(array_schema, :openai_strict) == array_schema
    end
  end

  describe "transform with real tool schemas" do
    test "transforms todo_add schema correctly" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "content" => %{
            "type" => "string",
            "description" => "The todo description"
          },
          "active_form" => %{
            "type" => "string",
            "description" => "Present continuous form"
          },
          "status" => %{
            "type" => "string",
            "enum" => ["pending", "in_progress", "completed"],
            "description" => "Initial status (defaults to 'pending')"
          }
        },
        "required" => ["content", "active_form"]
      }

      result = SchemaTransformer.transform(schema, :openai_strict)

      # Content and active_form should NOT be nullable (required)
      refute match?(%{"anyOf" => _}, result["properties"]["content"])
      refute match?(%{"anyOf" => _}, result["properties"]["active_form"])

      # Status should be nullable (optional)
      assert match?(%{"anyOf" => _}, result["properties"]["status"])

      # All should be in required array
      assert Enum.sort(result["required"]) == ["active_form", "content", "status"]

      # additionalProperties should be false
      assert result["additionalProperties"] == false
    end
  end
end
